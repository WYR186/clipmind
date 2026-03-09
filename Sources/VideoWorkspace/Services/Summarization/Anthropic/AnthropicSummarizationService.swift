import Foundation

struct AnthropicSummarizationService: LLMProviderProtocol {
    let type: ProviderType = .anthropic

    private let requestBuilder: AnthropicMessagesRequestBuilder
    private let mapper: AnthropicSummaryMapper
    private let client: any ProviderHTTPClientProtocol
    private let secretsStore: any SecretsStoreProtocol

    init(
        requestBuilder: AnthropicMessagesRequestBuilder = AnthropicMessagesRequestBuilder(),
        mapper: AnthropicSummaryMapper = AnthropicSummaryMapper(),
        client: any ProviderHTTPClientProtocol = URLSessionProviderHTTPClient(),
        secretsStore: any SecretsStoreProtocol
    ) {
        self.requestBuilder = requestBuilder
        self.mapper = mapper
        self.client = client
        self.secretsStore = secretsStore
    }

    func models() async throws -> [ModelDescriptor] {
        guard let apiKey = try await secretsStore.getSecret(for: ProviderType.anthropic.rawValue), !apiKey.isEmpty else {
            throw SummarizationError.apiKeyMissing(provider: .anthropic)
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await client.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw SummarizationError.requestFailed(provider: .anthropic, details: "status=\(response.statusCode)")
        }

        let decoded = try JSONDecoder().decode(AnthropicModelListResponse.self, from: data)
        return decoded.data.map { item in
            ModelDescriptor(
                id: item.id,
                displayName: item.displayName,
                contextWindow: item.contextWindow,
                capabilities: ProviderCapability(
                    supportsTranscription: false,
                    supportsSummarization: true,
                    supportsStreaming: true,
                    supportsStructuredOutput: true,
                    isLocalProvider: false,
                    capabilityTags: [.highQuality, .longContext]
                ),
                tags: [.highQuality, .longContext]
            )
        }
    }

    func connectionStatus() async -> ProviderConnectionStatus {
        do {
            let key = try await secretsStore.getSecret(for: ProviderType.anthropic.rawValue)
            return (key?.isEmpty == false) ? .connected : .unauthorized
        } catch {
            return .disconnected
        }
    }

    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult {
        guard let apiKey = try await secretsStore.getSecret(for: ProviderType.anthropic.rawValue), !apiKey.isEmpty else {
            throw SummarizationError.apiKeyMissing(provider: .anthropic)
        }

        let httpRequest = try requestBuilder.buildRequest(
            modelID: request.modelID,
            prompt: request.prompt,
            transcriptText: transcript.content,
            apiKey: apiKey
        )

        let (data, response) = try await client.data(for: httpRequest)
        guard (200...299).contains(response.statusCode) else {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw SummarizationError.requestFailed(provider: .anthropic, details: "status=\(response.statusCode) body=\(snippet)")
        }

        let decoded: AnthropicMessageResponse
        do {
            decoded = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
        } catch {
            throw SummarizationError.responseDecodeFailed(provider: .anthropic, details: error.localizedDescription)
        }

        let text = mapper.extractText(from: decoded)
        guard !text.isEmpty else {
            throw SummarizationError.responseDecodeFailed(provider: .anthropic, details: "empty output text")
        }

        return SummaryResult(
            taskID: taskID,
            provider: .anthropic,
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
            diagnostics: request.debugDiagnosticsEnabled ? "anthropic_status=\(response.statusCode)" : nil
        )
    }
}

private struct AnthropicModelListResponse: Decodable {
    let data: [AnthropicModelItem]
}

private struct AnthropicModelItem: Decodable {
    let id: String
    let displayName: String
    let contextWindow: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case contextWindow = "context_window"
    }
}
