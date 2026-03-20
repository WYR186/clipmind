import Foundation

struct TranslationService: TranslationServiceProtocol {
    private let providerRegistry: any ProviderRegistryProtocol
    private let requestValidator: TranslationRequestValidator
    private let mapper: SubtitleTranslationMapper
    private let exportService: any TranslationExportServiceProtocol
    private let logger: any AppLoggerProtocol

    init(
        providerRegistry: any ProviderRegistryProtocol,
        requestValidator: TranslationRequestValidator = TranslationRequestValidator(),
        mapper: SubtitleTranslationMapper = SubtitleTranslationMapper(),
        exportService: any TranslationExportServiceProtocol = TranslationExportService(),
        logger: any AppLoggerProtocol
    ) {
        self.providerRegistry = providerRegistry
        self.requestValidator = requestValidator
        self.mapper = mapper
        self.exportService = exportService
        self.logger = logger
    }

    func translate(
        request: TranslationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranslationResult {
        logger.debug("Translation requested: provider=\(request.provider.rawValue) model=\(request.modelID) mode=\(request.mode.rawValue)")
        try requestValidator.validate(request)
        progressHandler?(TaskProgressFactory.step(0.05, description: "Preparing translation"))

        guard let provider = await providerRegistry.provider(for: request.provider) else {
            throw TranslationError.providerUnavailable(request.provider)
        }

        let adapter = LLMTranslationProviderAdapter(provider: provider)
        let shouldUseSegmentFlow = request.mode == .subtitlePreserving
            || request.preserveTimestamps
            || request.outputFormats.contains(.srt)
            || request.outputFormats.contains(.vtt)

        let translatedSegments: [TranslationSegment]
        let translatedText: String

        if shouldUseSegmentFlow {
            let sourceSegments = mapper.sourceSegments(for: request)
            var segmentResults: [TranslationSegment] = []
            segmentResults.reserveCapacity(sourceSegments.count)

            for (index, segment) in sourceSegments.enumerated() {
                let prompt = mapper.prompt(
                    for: segment.text,
                    request: request,
                    segmentIndex: index,
                    totalSegments: sourceSegments.count
                )

                let translated = try await adapter.translate(
                    text: segment.text,
                    request: request,
                    prompt: prompt
                )

                segmentResults.append(
                    TranslationSegment(
                        index: segment.index,
                        startSeconds: segment.startSeconds,
                        endSeconds: segment.endSeconds,
                        sourceText: segment.text,
                        translatedText: translated
                    )
                )

                let fraction = 0.1 + (Double(index + 1) / Double(max(sourceSegments.count, 1))) * 0.6
                progressHandler?(TaskProgressFactory.step(fraction, description: "Translating segment \(index + 1)/\(sourceSegments.count)"))
            }

            translatedSegments = segmentResults
            translatedText = mapper.mergeTranslatedSegments(segmentResults)
        } else {
            let prompt = mapper.prompt(for: request.sourceText, request: request)
            translatedText = try await adapter.translate(
                text: request.sourceText,
                request: request,
                prompt: prompt
            )
            translatedSegments = []
            progressHandler?(TaskProgressFactory.step(0.7, description: "Translation generated"))
        }

        let bilingualEnabled = request.bilingualOutputEnabled || request.mode == .bilingual
        let bilingualText: String?
        if bilingualEnabled {
            if translatedSegments.isEmpty {
                bilingualText = mapper.makeBilingualText(sourceText: request.sourceText, translatedText: translatedText)
            } else {
                bilingualText = mapper.makeBilingualText(from: translatedSegments)
            }
        } else {
            bilingualText = nil
        }

        progressHandler?(TaskProgressFactory.step(0.85, description: "Exporting translation"))
        let artifacts = try exportService.write(
            request: request,
            translatedText: translatedText,
            bilingualText: bilingualText,
            translatedSegments: translatedSegments
        )

        progressHandler?(TaskProgressFactory.step(1, description: "Translation completed"))

        let result = TranslationResult(
            taskID: request.taskID,
            sourceTranscriptID: request.sourceTranscriptID,
            provider: request.provider,
            modelID: request.modelID,
            languagePair: request.languagePair,
            mode: request.mode,
            style: request.style,
            translatedText: translatedText,
            bilingualText: bilingualText,
            segments: translatedSegments,
            artifacts: artifacts,
            diagnostics: request.debugDiagnosticsEnabled ? "segments=\(translatedSegments.count)" : nil
        )
        logger.debug("Translation completed: task=\(request.taskID) artifacts=\(artifacts.count)")
        return result
    }
}

private struct LLMTranslationProviderAdapter {
    let provider: any LLMProviderProtocol

    func translate(text: String, request: TranslationRequest, prompt: String) async throws -> String {
        // TODO: Replace prompt-based bridge with provider-native translation endpoints when available.
        let pseudoTranscript = TranscriptItem(
            taskID: request.taskID,
            sourceType: .asr,
            languageCode: request.languagePair.sourceLanguage,
            format: .txt,
            content: text
        )

        let pseudoRequest = SummaryRequest(
            provider: request.provider,
            modelID: request.modelID,
            mode: .abstractSummary,
            length: .medium,
            outputLanguage: request.languagePair.targetLanguage,
            prompt: prompt,
            templateKind: .general,
            customPromptOverride: nil,
            chunkingStrategy: .sizeBased,
            structuredOutputPreferred: false,
            outputFormat: .plainText,
            debugDiagnosticsEnabled: request.debugDiagnosticsEnabled
        )

        do {
            let result = try await provider.summarize(taskID: request.taskID, transcript: pseudoTranscript, request: pseudoRequest)
            let normalized = normalize(result.content)
            if normalized.isEmpty {
                throw TranslationError.responseDecodeFailed(provider: request.provider, details: "empty translation content")
            }
            return normalized
        } catch let error as SummarizationError {
            throw mapProviderError(error, provider: request.provider, modelID: request.modelID)
        } catch let error as TranslationError {
            throw error
        } catch {
            throw TranslationError.requestFailed(provider: request.provider, details: error.localizedDescription)
        }
    }

    private func normalize(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            let parts = trimmed.components(separatedBy: "\n")
            if parts.count >= 3, parts.first?.hasPrefix("```") == true, parts.last == "```" {
                trimmed = parts.dropFirst().dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return trimmed
    }

    private func mapProviderError(
        _ error: SummarizationError,
        provider: ProviderType,
        modelID: String
    ) -> TranslationError {
        switch error {
        case .providerUnavailable:
            return .providerUnavailable(provider)
        case .modelUnavailable:
            return .modelUnavailable(provider: provider, modelID: modelID)
        case .apiKeyMissing:
            return .apiKeyMissing(provider: provider)
        case let .requestFailed(_, details):
            return .requestFailed(provider: provider, details: details)
        case let .responseDecodeFailed(_, details):
            return .responseDecodeFailed(provider: provider, details: details)
        case .localProviderNotRunning:
            return .requestFailed(provider: provider, details: error.diagnostics)
        default:
            return .requestFailed(provider: provider, details: error.diagnostics)
        }
    }
}
