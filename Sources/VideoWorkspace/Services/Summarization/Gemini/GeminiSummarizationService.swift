import Foundation

struct GeminiSummarizationService: LLMProviderProtocol {
    let type: ProviderType = .gemini

    private let requestBuilder: GeminiRequestBuilder
    private let mapper: GeminiSummaryMapper
    private let client: any ProviderHTTPClientProtocol
    private let secretsStore: any SecretsStoreProtocol

    init(
        requestBuilder: GeminiRequestBuilder = GeminiRequestBuilder(),
        mapper: GeminiSummaryMapper = GeminiSummaryMapper(),
        client: any ProviderHTTPClientProtocol = URLSessionProviderHTTPClient(),
        secretsStore: any SecretsStoreProtocol
    ) {
        self.requestBuilder = requestBuilder
        self.mapper = mapper
        self.client = client
        self.secretsStore = secretsStore
    }

    func models() async throws -> [ModelDescriptor] {
        // TODO: Replace with richer dynamic model metadata mapping.
        guard let apiKey = try await secretsStore.getSecret(for: ProviderType.gemini.rawValue), !apiKey.isEmpty else {
            throw SummarizationError.apiKeyMissing(provider: .gemini)
        }

        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        let (data, response) = try await client.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw SummarizationError.requestFailed(provider: .gemini, details: "status=\(response.statusCode)")
        }

        let decoded = try JSONDecoder().decode(GeminiModelListResponse.self, from: data)
        let models = decoded.models
            .filter { $0.supportedGenerationMethods?.contains("generateContent") == true }
            .map { item in
                ModelDescriptor(
                    id: item.name.replacingOccurrences(of: "models/", with: ""),
                    displayName: item.displayName ?? item.name,
                    contextWindow: Int(item.inputTokenLimit ?? 32_000),
                    capabilities: ProviderCapability(
                        supportsTranscription: false,
                        supportsSummarization: true,
                        supportsStreaming: true,
                        supportsStructuredOutput: true,
                        isLocalProvider: false,
                        capabilityTags: [.longContext, .structuredOutputFriendly, .fast]
                    ),
                    tags: [.longContext, .structuredOutputFriendly, .fast]
                )
            }

        return Array(models.prefix(30))
    }

    func connectionStatus() async -> ProviderConnectionStatus {
        do {
            let key = try await secretsStore.getSecret(for: ProviderType.gemini.rawValue)
            return (key?.isEmpty == false) ? .connected : .unauthorized
        } catch {
            return .disconnected
        }
    }

    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult {
        guard let apiKey = try await secretsStore.getSecret(for: ProviderType.gemini.rawValue), !apiKey.isEmpty else {
            throw SummarizationError.apiKeyMissing(provider: .gemini)
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
            throw SummarizationError.requestFailed(provider: .gemini, details: "status=\(response.statusCode) body=\(snippet)")
        }

        let decoded: GeminiGenerateContentResponse
        do {
            decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        } catch {
            throw SummarizationError.responseDecodeFailed(provider: .gemini, details: error.localizedDescription)
        }

        let text = mapper.extractText(from: decoded)
        guard !text.isEmpty else {
            throw SummarizationError.responseDecodeFailed(provider: .gemini, details: "empty output text")
        }

        return SummaryResult(
            taskID: taskID,
            provider: .gemini,
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
            diagnostics: request.debugDiagnosticsEnabled ? "gemini_status=\(response.statusCode)" : nil
        )
    }
}

private struct GeminiModelListResponse: Decodable {
    let models: [GeminiModelItem]
}

private struct GeminiModelItem: Decodable {
    let name: String
    let displayName: String?
    let inputTokenLimit: Double?
    let supportedGenerationMethods: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName
        case inputTokenLimit
        case supportedGenerationMethods
    }
}
