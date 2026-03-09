import Foundation

struct ModelDiscoveryService: ModelDiscoveryServiceProtocol {
    let providerRegistry: any ProviderRegistryProtocol

    func discoverModels(for provider: ProviderType) async throws -> [ModelDescriptor] {
        guard let service = await providerRegistry.provider(for: provider) else {
            throw SummarizationError.providerUnavailable(provider)
        }
        return try await service.models()
    }
}
