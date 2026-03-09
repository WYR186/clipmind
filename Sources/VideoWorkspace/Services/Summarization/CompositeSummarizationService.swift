import Foundation

struct CompositeSummarizationService: SummarizationServiceProtocol {
    private let providerRegistry: any ProviderRegistryProtocol
    private let requestValidator: SummaryRequestValidator
    private let templateRegistry: PromptTemplateRegistry
    private let chunkingService: SummaryChunkingService
    private let aggregationService: SummaryAggregationService
    private let outputNormalizer: SummaryOutputNormalizer
    private let fallbackService: (any SummarizationServiceProtocol)?
    private let allowFallbackToMock: Bool
    private let logger: any AppLoggerProtocol

    init(
        providerRegistry: any ProviderRegistryProtocol,
        requestValidator: SummaryRequestValidator = SummaryRequestValidator(),
        templateRegistry: PromptTemplateRegistry = PromptTemplateRegistry(),
        chunkingService: SummaryChunkingService = SummaryChunkingService(),
        aggregationService: SummaryAggregationService = SummaryAggregationService(),
        outputNormalizer: SummaryOutputNormalizer = SummaryOutputNormalizer(),
        fallbackService: (any SummarizationServiceProtocol)? = nil,
        allowFallbackToMock: Bool,
        logger: any AppLoggerProtocol
    ) {
        self.providerRegistry = providerRegistry
        self.requestValidator = requestValidator
        self.templateRegistry = templateRegistry
        self.chunkingService = chunkingService
        self.aggregationService = aggregationService
        self.outputNormalizer = outputNormalizer
        self.fallbackService = fallbackService
        self.allowFallbackToMock = allowFallbackToMock
        self.logger = logger
    }

    func summarize(
        request: SummarizationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> SummaryResult {
        do {
            return try await summarizeInternal(request: request, progressHandler: progressHandler)
        } catch {
            guard allowFallbackToMock,
                  let fallbackService,
                  shouldFallback(for: error) else {
                throw error
            }
            logger.info("Falling back to mock summarization service")
            return try await fallbackService.summarize(request: request, progressHandler: progressHandler)
        }
    }

    private func summarizeInternal(
        request: SummarizationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> SummaryResult {
        try requestValidator.validate(request)
        progressHandler?(TaskProgressFactory.step(0.05, description: "Preparing summary"))

        var summaryRequest = request.summaryRequest
        let basePrompt = templateRegistry.renderPrompt(for: summaryRequest)
        summaryRequest = withPrompt(summaryRequest, prompt: basePrompt)

        guard let provider = await providerRegistry.provider(for: summaryRequest.provider) else {
            throw SummarizationError.providerUnavailable(summaryRequest.provider)
        }

        let chunks = try chunkingService.makeChunks(for: request)

        var partialTexts: [String] = []
        var normalizedPayloads: [StructuredSummaryPayload] = []
        for (index, chunk) in chunks.enumerated() {
            let chunkPrompt = chunkPromptText(basePrompt: basePrompt, chunk: chunk, totalChunks: chunks.count)
            let chunkRequest = withPrompt(summaryRequest, prompt: chunkPrompt)
            let chunkTranscript = TranscriptItem(
                taskID: request.taskID,
                sourceType: request.transcript.sourceType,
                languageCode: request.transcript.languageCode,
                format: .txt,
                content: chunk.text,
                segments: [],
                artifacts: request.transcript.artifacts,
                backend: request.transcript.backend,
                modelID: request.transcript.modelID,
                detectedLanguage: request.transcript.detectedLanguage
            )

            let partial = try await provider.summarize(taskID: request.taskID, transcript: chunkTranscript, request: chunkRequest)
            partialTexts.append(partial.content)

            if let payload = try? outputNormalizer.normalize(text: partial.content, mode: summaryRequest.mode) {
                normalizedPayloads.append(payload)
            }

            let fraction = 0.1 + (Double(index + 1) / Double(max(chunks.count, 1))) * 0.65
            progressHandler?(TaskProgressFactory.step(fraction, description: "Summarizing chunk \(index + 1)/\(chunks.count)"))
        }

        let combined = try aggregationService.combineChunkSummaries(partialTexts)

        let finalSummaryText: String
        if chunks.count > 1 {
            let reducePrompt = reducePromptText(basePrompt: basePrompt)
            let reduceRequest = withPrompt(summaryRequest, prompt: reducePrompt)
            let reduceTranscript = TranscriptItem(
                taskID: request.taskID,
                sourceType: .asr,
                languageCode: request.transcript.languageCode,
                format: .txt,
                content: combined
            )
            let reduced = try await provider.summarize(taskID: request.taskID, transcript: reduceTranscript, request: reduceRequest)
            finalSummaryText = reduced.content
        } else {
            finalSummaryText = partialTexts.first ?? combined
        }

        progressHandler?(TaskProgressFactory.step(0.9, description: "Normalizing summary"))

        let finalPayload = try outputNormalizer.normalize(text: finalSummaryText, mode: summaryRequest.mode)
        let merged = aggregationService.mergeStructuredPayloads(normalizedPayloads + [finalPayload])

        let markdown = outputNormalizer.toMarkdown(from: merged)
        let plain = outputNormalizer.toPlainText(from: merged)
        let finalContent: String
        switch summaryRequest.outputFormat {
        case .markdown:
            finalContent = markdown
        case .plainText:
            finalContent = plain
        case .json:
            let data = try JSONEncoder().encode(merged)
            finalContent = String(data: data, encoding: .utf8) ?? markdown
        }

        progressHandler?(TaskProgressFactory.step(1.0, description: "Summary completed"))

        return SummaryResult(
            taskID: request.taskID,
            provider: summaryRequest.provider,
            modelID: summaryRequest.modelID,
            mode: summaryRequest.mode,
            length: summaryRequest.length,
            content: finalContent,
            structured: merged,
            markdown: markdown,
            plainText: plain,
            artifacts: [],
            templateKind: summaryRequest.templateKind,
            outputLanguage: summaryRequest.outputLanguage,
            diagnostics: summaryRequest.debugDiagnosticsEnabled ? "chunks=\(chunks.count)" : nil
        )
    }

    private func withPrompt(_ request: SummaryRequest, prompt: String) -> SummaryRequest {
        SummaryRequest(
            provider: request.provider,
            modelID: request.modelID,
            mode: request.mode,
            length: request.length,
            outputLanguage: request.outputLanguage,
            prompt: prompt,
            templateKind: request.templateKind,
            customPromptOverride: request.customPromptOverride,
            chunkingStrategy: request.chunkingStrategy,
            structuredOutputPreferred: request.structuredOutputPreferred,
            outputFormat: request.outputFormat,
            debugDiagnosticsEnabled: request.debugDiagnosticsEnabled
        )
    }

    private func chunkPromptText(basePrompt: String, chunk: TranscriptChunk, totalChunks: Int) -> String {
        var prompt = basePrompt + "\n\nYou are processing chunk \(chunk.index + 1) of \(totalChunks)."
        if let start = chunk.startSeconds, let end = chunk.endSeconds {
            prompt += " Time window: \(Int(start))s-\(Int(end))s."
        }
        return prompt
    }

    private func reducePromptText(basePrompt: String) -> String {
        basePrompt + "\n\nYou are now aggregating chunk summaries. Remove duplicates and produce one coherent final summary."
    }

    private func shouldFallback(for error: Error) -> Bool {
        guard let typed = error as? SummarizationError else {
            return false
        }

        switch typed {
        case .providerUnavailable, .localProviderNotRunning:
            return true
        case .apiKeyMissing, .modelUnavailable, .invalidSummaryRequest, .transcriptMissing:
            return false
        default:
            return false
        }
    }
}
