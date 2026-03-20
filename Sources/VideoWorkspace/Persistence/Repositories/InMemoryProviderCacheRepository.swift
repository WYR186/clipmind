import Foundation

actor InMemoryProviderCacheRepository: ProviderCacheRepositoryProtocol {
    private var storage: [ProviderType: ProviderCacheEntry] = [:]

    func cacheEntry(for provider: ProviderType) async -> ProviderCacheEntry? {
        storage[provider]
    }

    func saveCacheEntry(_ entry: ProviderCacheEntry) async {
        storage[entry.provider] = entry
    }

    func invalidateCache(for provider: ProviderType) async {
        guard let entry = storage[provider] else { return }
        storage[provider] = ProviderCacheEntry(
            provider: provider,
            models: entry.models,
            updatedAt: Date(),
            validityMarker: "invalid"
        )
    }
}
