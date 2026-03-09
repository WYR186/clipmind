import Foundation

actor InMemoryHistoryRepository: HistoryRepositoryProtocol {
    private var storage: [HistoryEntry] = []
    private var continuations: [UUID: AsyncStream<[HistoryEntry]>.Continuation] = [:]

    func addHistoryEntry(_ entry: HistoryEntry) async {
        storage.insert(entry, at: 0)
        publish()
    }

    func allHistoryEntries() async -> [HistoryEntry] {
        storage.sorted { $0.createdAt > $1.createdAt }
    }

    func historyStream() async -> AsyncStream<[HistoryEntry]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { [weak self] in
                await self?.register(continuation: continuation, token: token)
            }
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(token: token)
                }
            }
        }
    }

    private func register(continuation: AsyncStream<[HistoryEntry]>.Continuation, token: UUID) {
        continuations[token] = continuation
        continuation.yield(storage.sorted { $0.createdAt > $1.createdAt })
    }

    private func removeContinuation(token: UUID) {
        continuations[token] = nil
    }

    private func publish() {
        let snapshot = storage.sorted { $0.createdAt > $1.createdAt }
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }
}
