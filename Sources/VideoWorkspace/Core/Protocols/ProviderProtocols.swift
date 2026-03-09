import Foundation

public protocol ProviderRegistryProtocol: Sendable {
    func availableProviders() async -> [ProviderType]
    func connectionStatus(for provider: ProviderType) async -> ProviderConnectionStatus
    func provider(for providerType: ProviderType) async -> (any LLMProviderProtocol)?
}

public protocol ModelDiscoveryServiceProtocol: Sendable {
    func discoverModels(for provider: ProviderType) async throws -> [ModelDescriptor]
}
