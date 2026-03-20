import Foundation

struct CachedModelDiscoveryService: ModelDiscoveryServiceProtocol {
    let upstream: any ModelDiscoveryServiceProtocol
    let cacheRepository: any ProviderCacheRepositoryProtocol
    let logger: any AppLoggerProtocol
    let cacheTTL: TimeInterval

    init(
        upstream: any ModelDiscoveryServiceProtocol,
        cacheRepository: any ProviderCacheRepositoryProtocol,
        logger: any AppLoggerProtocol,
        cacheTTL: TimeInterval = 60 * 60
    ) {
        self.upstream = upstream
        self.cacheRepository = cacheRepository
        self.logger = logger
        self.cacheTTL = cacheTTL
    }

    func discoverModels(for provider: ProviderType) async throws -> [ModelDescriptor] {
        if let cached = await cacheRepository.cacheEntry(for: provider),
           cached.isValid,
           Date().timeIntervalSince(cached.updatedAt) <= cacheTTL {
            return cached.models
        }

        do {
            let models = try await upstream.discoverModels(for: provider)
            await cacheRepository.saveCacheEntry(
                ProviderCacheEntry(provider: provider, models: models, updatedAt: Date(), validityMarker: "fresh")
            )
            return models
        } catch {
            logger.error("Model discovery failed (\(provider.rawValue)): \(error.localizedDescription)")
            if let stale = await cacheRepository.cacheEntry(for: provider), !stale.models.isEmpty {
                return stale.models
            }
            throw error
        }
    }
}
