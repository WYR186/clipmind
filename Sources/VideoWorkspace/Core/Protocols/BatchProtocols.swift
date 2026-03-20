import Foundation

public protocol BatchJobRepositoryProtocol: Sendable {
    func createBatch(job: BatchJob, items: [BatchJobItem]) async
    func updateBatch(_ job: BatchJob) async
    func updateItem(_ item: BatchJobItem) async
    func batch(id: BatchJobID) async -> BatchJob?
    func items(forBatchID batchID: BatchJobID) async -> [BatchJobItem]
    func allBatches() async -> [BatchJob]
    func batchStream() async -> AsyncStream<[BatchJob]>
    func itemStream(forBatchID batchID: BatchJobID) async -> AsyncStream<[BatchJobItem]>
}

public protocol BatchCreationServiceProtocol: Sendable {
    func createBatch(request: BatchCreationRequest) async throws -> BatchJob
}

public protocol BatchExecutionServiceProtocol: Sendable {
    func start(batchJobID: BatchJobID) async
    func pause(batchJobID: BatchJobID) async
    func resume(batchJobID: BatchJobID) async
    func cancelRemainingItems(batchJobID: BatchJobID) async
    func retryFailedItems(batchJobID: BatchJobID) async
    func executionSummary(batchJobID: BatchJobID) async -> BatchExecutionSummary?
}
