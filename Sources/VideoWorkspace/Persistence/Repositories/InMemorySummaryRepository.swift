import Foundation

actor InMemorySummaryRepository: SummaryRepositoryProtocol {
    private var storage: [UUID: SummaryResult] = [:]

    func upsertSummary(_ summary: SummaryResult, historyID: UUID?) async {
        storage[summary.id] = summary
    }

    func summary(id: UUID) async -> SummaryResult? {
        storage[id]
    }
}
