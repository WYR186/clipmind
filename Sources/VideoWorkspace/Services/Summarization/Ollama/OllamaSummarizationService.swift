import Foundation

struct OllamaSummarizationService: LLMProviderProtocol {
    let type: ProviderType = .ollama

    private let requestBuilder: OllamaRequestBuilder
    private let mapper: OllamaSummaryMapper
    private let client: any ProviderHTTPClientProtocol
    private let tagsEndpoint: URL

    init(
        requestBuilder: OllamaRequestBuilder = OllamaRequestBuilder(),
        mapper: OllamaSummaryMapper = OllamaSummaryMapper(),
        client: any ProviderHTTPClientProtocol = URLSessionProviderHTTPClient(),
        tagsEndpoint: URL = URL(string: "http://localhost:11434/api/tags")!
    ) {
        self.requestBuilder = requestBuilder
        self.mapper = mapper
        self.client = client
        self.tagsEndpoint = tagsEndpoint
    }

    func models() async throws -> [ModelDescriptor] {
        var request = URLRequest(url: tagsEndpoint)
        request.httpMethod = "GET"

        let (data, response) = try await client.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw SummarizationError.localProviderNotRunning(provider: .ollama)
        }

        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models.map { item in
            ModelDescriptor(
                id: item.name,
                displayName: item.name,
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
            throw SummarizationError.requestFailed(provider: .ollama, details: "status=\(response.statusCode) body=\(snippet)")
        }

        let decoded: OllamaChatResponse
        do {
            decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        } catch {
            throw SummarizationError.responseDecodeFailed(provider: .ollama, details: error.localizedDescription)
        }

        let text = mapper.extractText(from: decoded)
        guard !text.isEmpty else {
            throw SummarizationError.responseDecodeFailed(provider: .ollama, details: "empty output text")
        }

        return SummaryResult(
            taskID: taskID,
            provider: .ollama,
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
            diagnostics: request.debugDiagnosticsEnabled ? "ollama_status=\(response.statusCode)" : nil
        )
    }
}
