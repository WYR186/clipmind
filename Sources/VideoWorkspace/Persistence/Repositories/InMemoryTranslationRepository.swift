import Foundation

actor InMemoryTranslationRepository: TranslationRepositoryProtocol {
    private var storage: [UUID: TranslationResult] = [:]

    func upsertTranslation(_ translation: TranslationResult, historyID: UUID?) async {
        _ = historyID
        storage[translation.id] = translation
    }

    func translation(id: UUID) async -> TranslationResult? {
        storage[id]
    }
}
