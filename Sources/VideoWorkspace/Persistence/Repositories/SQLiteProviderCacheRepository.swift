import Foundation

actor SQLiteProviderCacheRepository: ProviderCacheRepositoryProtocol {
    private let databaseManager: DatabaseManager
    private let logger: any AppLoggerProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(databaseManager: DatabaseManager, logger: any AppLoggerProtocol) {
        self.databaseManager = databaseManager
        self.logger = logger
    }

    func cacheEntry(for provider: ProviderType) async -> ProviderCacheEntry? {
        do {
            let rows = try await databaseManager.query(
                sql: ProviderCacheSQL.selectByProvider,
                bindings: [.text(provider.rawValue)]
            )

            guard let row = rows.first,
                  let payload = row.text("cached_model_payload"),
                  let payloadData = payload.data(using: .utf8)
            else {
                return nil
            }

            let models = try decoder.decode([ModelDescriptor].self, from: payloadData)
            let updatedAtRaw = row.double("updated_at") ?? 0
            let validity = row.text("validity_marker") ?? "invalid"

            return ProviderCacheEntry(
                provider: provider,
                models: models,
                updatedAt: Date(timeIntervalSince1970: updatedAtRaw),
                validityMarker: validity
            )
        } catch {
            logger.error("Provider cache read failed (\(provider.rawValue)): \(error.localizedDescription)")
            return nil
        }
    }

    func saveCacheEntry(_ entry: ProviderCacheEntry) async {
        do {
            let payloadData = try encoder.encode(entry.models)
            guard let payload = String(data: payloadData, encoding: .utf8) else {
                throw PersistenceError.providerCacheWriteFailed(details: "Invalid UTF-8 payload")
            }

            try await databaseManager.execute(
                sql: ProviderCacheSQL.upsert,
                bindings: [
                    .text(entry.provider.rawValue),
                    .text(payload),
                    .double(entry.updatedAt.timeIntervalSince1970),
                    .text(entry.validityMarker)
                ]
            )
        } catch {
            logger.error("Provider cache write failed (\(entry.provider.rawValue)): \(error.localizedDescription)")
        }
    }

    func invalidateCache(for provider: ProviderType) async {
        do {
            try await databaseManager.execute(
                sql: ProviderCacheSQL.invalidate,
                bindings: [
                    .double(Date().timeIntervalSince1970),
                    .text(provider.rawValue)
                ]
            )
        } catch {
            logger.error("Provider cache invalidation failed (\(provider.rawValue)): \(error.localizedDescription)")
        }
    }
}
