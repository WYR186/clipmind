import Foundation

struct LMStudioSummarizationService: LLMProviderProtocol {
    let type: ProviderType = .lmStudio

    private let requestBuilder: LMStudioRequestBuilder
    private let mapper: LMStudioSummaryMapper
    private let client: any ProviderHTTPClientProtocol
    private let modelsEndpoint: URL

    init(
        requestBuilder: LMStudioRequestBuilder = LMStudioRequestBuilder(),
        mapper: LMStudioSummaryMapper = LMStudioSummaryMapper(),
        client: any ProviderHTTPClientProtocol = URLSessionProviderHTTPClient(),
        modelsEndpoint: URL = URL(string: "http://localhost:1234/v1/models")!
    ) {
        self.requestBuilder = requestBuilder
        self.mapper = mapper
        self.client = client
        self.modelsEndpoint = modelsEndpoint
    }

    func models() async throws -> [ModelDescriptor] {
        var request = URLRequest(url: modelsEndpoint)
        request.httpMethod = "GET"

        let (data, response) = try await client.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw SummarizationError.localProviderNotRunning(provider: .lmStudio)
        }

        let decoded = try JSONDecoder().decode(LMStudioModelListResponse.self, from: data)
        return decoded.data.map { item in
            ModelDescriptor(
                id: item.id,
                displayName: item.id,
                contextWindow: 32_000,
                capabilities: ProviderCapability(
                    supportsTranscription: false,
                    supportsSummarization: true,
                    supportsStreaming: true,
                    supportsStructuredOutput: false,
                    isLocalProvider: true,
                    capabilityTags: [.localPrivacy]
                ),
                tags: [.localPrivacy]
            )
        }
    }

    func connectionStatus() async -> ProviderConnectionStatus {
        do {
            _ = try await models()
            return .connected
        } catch {
            return .disconnected
        }
    }

    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult {
        let httpRequest = try requestBuilder.buildRequest(
            modelID: request.modelID,
            prompt: request.prompt,
            transcriptText: transcript.content,
            structured: request.structuredOutputPreferred
        )

        let (data, response) = try await client.data(for: httpRequest)
        guard (200...299).contains(response.statusCode) else {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw SummarizationError.requestFailed(provider: .lmStudio, details: "status=\(response.statusCode) body=\(snippet)")
        }

        let decoded: LMStudioChatResponse
        do {
            decoded = try JSONDecoder().decode(LMStudioChatResponse.self, from: data)
        } catch {
            throw SummarizationError.responseDecodeFailed(provider: .lmStudio, details: error.localizedDescription)
        }

        let text = mapper.extractText(from: decoded)
        guard !text.isEmpty else {
            throw SummarizationError.responseDecodeFailed(provider: .lmStudio, details: "empty output text")
        }

        return SummaryResult(
            taskID: taskID,
            provider: .lmStudio,
            modelID: request.modelID,
            mode: request.mode,
            length: request.length,
            content: text,
            structured: nil,
            markdown: text,
            plainText: text,
            artifacts: [],
            templateKind: request.templateKind,
            outputLanguage: request.outputLanguage,
            diagnostics: request.debugDiagnosticsEnabled ? "lmstudio_status=\(response.statusCode)" : nil
        )
    }
}
