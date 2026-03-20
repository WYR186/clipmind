import Foundation

actor InMemoryBatchJobRepository: BatchJobRepositoryProtocol {
    private var batchStorage: [BatchJobID: BatchJob] = [:]
    private var itemStorage: [BatchJobID: [UUID: BatchJobItem]] = [:]

    private var batchContinuations: [UUID: AsyncStream<[BatchJob]>.Continuation] = [:]
    private var itemContinuationsByBatchID: [BatchJobID: [UUID: AsyncStream<[BatchJobItem]>.Continuation]] = [:]

    func createBatch(job: BatchJob, items: [BatchJobItem]) async {
        batchStorage[job.id] = job
        itemStorage[job.id] = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        await publishBatches()
        await publishItems(for: job.id)
    }

    func updateBatch(_ job: BatchJob) async {
        batchStorage[job.id] = job
        await publishBatches()
    }

    func updateItem(_ item: BatchJobItem) async {
        var items = itemStorage[item.batchJobID] ?? [:]
        items[item.id] = item
        itemStorage[item.batchJobID] = items
        await publishItems(for: item.batchJobID)
    }

    func batch(id: BatchJobID) async -> BatchJob? {
        batchStorage[id]
    }

    func items(forBatchID batchID: BatchJobID) async -> [BatchJobItem] {
        let items = itemStorage[batchID] ?? [:]
        return items.values.sorted { $0.createdAt < $1.createdAt }
    }

    func allBatches() async -> [BatchJob] {
        batchStorage.values.sorted { $0.createdAt > $1.createdAt }
    }

    func batchStream() async -> AsyncStream<[BatchJob]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { [weak self] in
                await self?.registerBatchContinuation(continuation, token: token)
            }
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeBatchContinuation(token: token)
                }
            }
        }
    }

    func itemStream(forBatchID batchID: BatchJobID) async -> AsyncStream<[BatchJobItem]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { [weak self] in
                await self?.registerItemContinuation(continuation, token: token, batchID: batchID)
            }
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeItemContinuation(token: token, batchID: batchID)
                }
            }
        }
    }

    private func registerBatchContinuation(_ continuation: AsyncStream<[BatchJob]>.Continuation, token: UUID) async {
        batchContinuations[token] = continuation
        continuation.yield(await allBatches())
    }

    private func removeBatchContinuation(token: UUID) {
        batchContinuations[token] = nil
    }

    private func registerItemContinuation(
        _ continuation: AsyncStream<[BatchJobItem]>.Continuation,
        token: UUID,
        batchID: BatchJobID
    ) async {
        var bucket = itemContinuationsByBatchID[batchID] ?? [:]
        bucket[token] = continuation
        itemContinuationsByBatchID[batchID] = bucket
        continuation.yield(await items(forBatchID: batchID))
    }

    private func removeItemContinuation(token: UUID, batchID: BatchJobID) {
        guard var bucket = itemContinuationsByBatchID[batchID] else {
            return
        }
        bucket[token] = nil
        if bucket.isEmpty {
            itemContinuationsByBatchID[batchID] = nil
        } else {
            itemContinuationsByBatchID[batchID] = bucket
        }
    }

    private func publishBatches() async {
        let snapshot = await allBatches()
        for continuation in batchContinuations.values {
            continuation.yield(snapshot)
        }
    }

    private func publishItems(for batchID: BatchJobID) async {
        guard let bucket = itemContinuationsByBatchID[batchID] else {
            return
        }
        let snapshot = await items(forBatchID: batchID)
        for continuation in bucket.values {
            continuation.yield(snapshot)
        }
    }
}
