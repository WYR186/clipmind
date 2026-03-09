import Foundation

actor InMemoryTaskRepository: TaskRepositoryProtocol {
    private var storage: [UUID: TaskItem] = [:]
    private var continuations: [UUID: AsyncStream<[TaskItem]>.Continuation] = [:]

    func addTask(_ task: TaskItem) async {
        storage[task.id] = task
        publish()
    }

    func updateTask(_ task: TaskItem) async {
        storage[task.id] = task
        publish()
    }

    func task(id: UUID) async -> TaskItem? {
        storage[id]
    }

    func allTasks() async -> [TaskItem] {
        storage.values.sorted { $0.createdAt > $1.createdAt }
    }

    func taskStream() async -> AsyncStream<[TaskItem]> {
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

    private func register(continuation: AsyncStream<[TaskItem]>.Continuation, token: UUID) {
        continuations[token] = continuation
        continuation.yield(storage.values.sorted { $0.createdAt > $1.createdAt })
    }

    private func removeContinuation(token: UUID) {
        continuations[token] = nil
    }

    private func publish() {
        let snapshot = storage.values.sorted { $0.createdAt > $1.createdAt }
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }
}
