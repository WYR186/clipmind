import Foundation

actor ProviderRegistry: ProviderRegistryProtocol {
    private let providers: [ProviderType: any LLMProviderProtocol]

    init(providers: [ProviderType: any LLMProviderProtocol]) {
        self.providers = providers
    }

    func availableProviders() async -> [ProviderType] {
        Array(providers.keys).sorted { $0.rawValue < $1.rawValue }
    }

    func connectionStatus(for provider: ProviderType) async -> ProviderConnectionStatus {
        guard let provider = providers[provider] else {
            return .disconnected
        }
        return await provider.connectionStatus()
    }

    func provider(for providerType: ProviderType) async -> (any LLMProviderProtocol)? {
        providers[providerType]
    }
}
