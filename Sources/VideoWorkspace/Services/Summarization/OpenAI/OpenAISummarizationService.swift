import Foundation

struct OpenAISummarizationService: LLMProviderProtocol {
    let type: ProviderType = .openAI

    private let requestBuilder: OpenAIResponsesRequestBuilder
    private let mapper: OpenAISummaryMapper
    private let client: any ProviderHTTPClientProtocol
    private let secretsStore: any SecretsStoreProtocol

    init(
        requestBuilder: OpenAIResponsesRequestBuilder = OpenAIResponsesRequestBuilder(),
        mapper: OpenAISummaryMapper = OpenAISummaryMapper(),
        client: any ProviderHTTPClientProtocol = URLSessionProviderHTTPClient(),
        secretsStore: any SecretsStoreProtocol
    ) {
        self.requestBuilder = requestBuilder
        self.mapper = mapper
        self.client = client
        self.secretsStore = secretsStore
    }

    func models() async throws -> [ModelDescriptor] {
        guard let apiKey = try await secretsStore.getSecret(for: ProviderType.openAI.rawValue),
              !apiKey.isEmpty else {
            throw SummarizationError.apiKeyMissing(provider: .openAI)
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await client.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw SummarizationError.requestFailed(provider: .openAI, details: "status=\(response.statusCode)")
        }

        let decoded = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data)
        return decoded.data.prefix(30).map { item in
            ModelDescriptor(
                id: item.id,
                displayName: item.id,
                contextWindow: item.id.contains("128k") ? 128_000 : 32_000,
                capabilities: ProviderCapability(
                    supportsTranscription: false,
                    supportsSummarization: true,
                    supportsStreaming: true,
                    supportsStructuredOutput: true,
                    isLocalProvider: false,
                    capabilityTags: [.highQuality, .structuredOutputFriendly]
                ),
                tags: recommendedTags(for: item.id)
            )
        }
    }

    func connectionStatus() async -> ProviderConnectionStatus {
        do {
            let key = try await secretsStore.getSecret(for: ProviderType.openAI.rawValue)
            return (key?.isEmpty == false) ? .connected : .unauthorized
        } catch {
            return .disconnected
        }
    }

    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult {
        guard let apiKey = try await secretsStore.getSecret(for: ProviderType.openAI.rawValue),
              !apiKey.isEmpty else {
            throw SummarizationError.apiKeyMissing(provider: .openAI)
        }

        let httpRequest = try requestBuilder.buildRequest(
            modelID: request.modelID,
            prompt: request.prompt,
            transcriptText: transcript.content,
            apiKey: apiKey,
            structured: request.structuredOutputPreferred
        )

        let (data, response) = try await client.data(for: httpRequest)
        guard (200...299).contains(response.statusCode) else {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw SummarizationError.requestFailed(provider: .openAI, details: "status=\(response.statusCode) body=\(snippet)")
        }

        let decoded: OpenAIResponsesResponse
        do {
            decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        } catch {
            throw SummarizationError.responseDecodeFailed(provider: .openAI, details: error.localizedDescription)
        }

        let text = mapper.extractText(from: decoded)
        guard !text.isEmpty else {
            throw SummarizationError.responseDecodeFailed(provider: .openAI, details: "empty output text")
        }

        return SummaryResult(
            taskID: taskID,
            provider: .openAI,
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
            diagnostics: request.debugDiagnosticsEnabled ? "openai_status=\(response.statusCode)" : nil
        )
    }

    private func recommendedTags(for modelID: String) -> [ModelCapabilityTag] {
        var tags: [ModelCapabilityTag] = [.highQuality, .structuredOutputFriendly]
        if modelID.contains("mini") || modelID.contains("nano") {
            tags.append(.lowCost)
            tags.append(.fast)
        }
        if modelID.contains("128k") {
            tags.append(.longContext)
        }
        return Array(Set(tags))
    }
}

private struct OpenAIModelListResponse: Decodable {
    let data: [OpenAIModelItem]
}

private struct OpenAIModelItem: Decodable {
    let id: String
}
