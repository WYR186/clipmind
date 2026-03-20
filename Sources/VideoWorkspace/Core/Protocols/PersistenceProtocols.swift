import Foundation

public protocol TaskRepositoryProtocol: Sendable {
    func addTask(_ task: TaskItem) async
    func updateTask(_ task: TaskItem) async
    func task(id: UUID) async -> TaskItem?
    func allTasks() async -> [TaskItem]
    func taskStream() async -> AsyncStream<[TaskItem]>
}

public protocol HistoryRepositoryProtocol: Sendable {
    func addHistoryEntry(_ entry: HistoryEntry) async
    func allHistoryEntries() async -> [HistoryEntry]
    func historyStream() async -> AsyncStream<[HistoryEntry]>
}

public protocol SettingsRepositoryProtocol: Sendable {
    func loadSettings() async -> AppSettings
    func saveSettings(_ settings: AppSettings) async
}

public protocol TranscriptRepositoryProtocol: Sendable {
    func upsertTranscript(_ transcript: TranscriptItem, historyID: UUID?) async
    func transcript(id: UUID) async -> TranscriptItem?
}

public protocol SummaryRepositoryProtocol: Sendable {
    func upsertSummary(_ summary: SummaryResult, historyID: UUID?) async
    func summary(id: UUID) async -> SummaryResult?
}

public protocol TranslationRepositoryProtocol: Sendable {
    func upsertTranslation(_ translation: TranslationResult, historyID: UUID?) async
    func translation(id: UUID) async -> TranslationResult?
}

public protocol ArtifactRepositoryProtocol: Sendable {
    func addArtifacts(_ artifacts: [ArtifactRecord]) async
    func artifacts(forTaskID taskID: UUID) async -> [ArtifactRecord]
    func artifacts(forHistoryID historyID: UUID) async -> [ArtifactRecord]
    func artifacts(ofType type: ArtifactType) async -> [ArtifactRecord]
}

public protocol ProviderCacheRepositoryProtocol: Sendable {
    func cacheEntry(for provider: ProviderType) async -> ProviderCacheEntry?
    func saveCacheEntry(_ entry: ProviderCacheEntry) async
    func invalidateCache(for provider: ProviderType) async
}

public protocol SecretsStoreProtocol: Sendable {
    func setSecret(_ secret: String, for key: String) async throws
    func getSecret(for key: String) async throws -> String?
    func removeSecret(for key: String) async throws
}

public extension SecretsStoreProtocol {
    func updateSecret(_ secret: String, for key: String) async throws {
        try await setSecret(secret, for: key)
    }

    func hasSecret(for key: String) async throws -> Bool {
        guard let value = try await getSecret(for: key) else {
            return false
        }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
