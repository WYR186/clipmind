import Foundation

struct MockLLMProvider: LLMProviderProtocol {
    let type: ProviderType
    let modelList: [ModelDescriptor]

    func models() async throws -> [ModelDescriptor] {
        modelList
    }

    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult {
        let prefix: String
        switch request.mode {
        case .abstractSummary:
            prefix = "Summary"
        case .keyPoints:
            prefix = "Key Points"
        case .chapters:
            prefix = "Chapters"
        }

        let content = "[\(type.rawValue)/\(request.modelID)] \(prefix): \(MockSamples.summaryText)"
        return SummaryResult(
            taskID: taskID,
            provider: type,
            modelID: request.modelID,
            mode: request.mode,
            length: request.length,
            content: content
        )
    }
}

actor MockProviderRegistry: ProviderRegistryProtocol, ModelDiscoveryServiceProtocol {
    private let providers: [ProviderType: MockLLMProvider]

    init() {
        let standardCapability = ProviderCapability(
            supportsTranscription: false,
            supportsSummarization: true,
            supportsStreaming: true,
            supportsStructuredOutput: true,
            isLocalProvider: false,
            capabilityTags: [.fast]
        )

        providers = [
            .openAI: MockLLMProvider(
                type: .openAI,
                modelList: [
                    ModelDescriptor(id: "gpt-4.1-mini", displayName: "GPT-4.1 mini", contextWindow: 128_000, capabilities: standardCapability)
                ]
            ),
            .anthropic: MockLLMProvider(
                type: .anthropic,
                modelList: [
                    ModelDescriptor(id: "claude-3-7-sonnet", displayName: "Claude 3.7 Sonnet", contextWindow: 200_000, capabilities: standardCapability)
                ]
            ),
            .gemini: MockLLMProvider(
                type: .gemini,
                modelList: [
                    ModelDescriptor(id: "gemini-2.0-flash", displayName: "Gemini 2.0 Flash", contextWindow: 1_000_000, capabilities: standardCapability)
                ]
            ),
            .ollama: MockLLMProvider(
                type: .ollama,
                modelList: [
                    ModelDescriptor(
                        id: "qwen3:8b",
                        displayName: "Qwen3 8B",
                        contextWindow: 32_000,
                        capabilities: ProviderCapability(
                            supportsTranscription: false,
                            supportsSummarization: true,
                            supportsStreaming: true,
                            supportsStructuredOutput: false,
                            isLocalProvider: true,
                            capabilityTags: [.localPrivacy]
                        )
                    )
                ]
            ),
            .lmStudio: MockLLMProvider(
                type: .lmStudio,
                modelList: [
                    ModelDescriptor(
                        id: "local-model-a",
                        displayName: "Local Model A",
                        contextWindow: 16_000,
                        capabilities: ProviderCapability(
                            supportsTranscription: false,
                            supportsSummarization: true,
                            supportsStreaming: true,
                            supportsStructuredOutput: false,
                            isLocalProvider: true,
                            capabilityTags: [.localPrivacy]
                        )
                    )
                ]
            )
        ]
    }

    func availableProviders() async -> [ProviderType] {
        ProviderType.allCases
    }

    func connectionStatus(for provider: ProviderType) async -> ProviderConnectionStatus {
        providers[provider] == nil ? .disconnected : .connected
    }

    func provider(for providerType: ProviderType) async -> (any LLMProviderProtocol)? {
        providers[providerType]
    }

    func discoverModels(for provider: ProviderType) async throws -> [ModelDescriptor] {
        guard let models = providers[provider]?.modelList else {
            throw AppServiceError.modelUnavailable
        }
        return models
    }
}
