import Foundation

public struct BatchExecutionSummary: Codable, Hashable, Sendable {
    public let batchJobID: UUID
    public let status: BatchJobStatus
    public let progress: BatchJobProgress
    public let failedItemIDs: [UUID]
    public let cancelledItemIDs: [UUID]
    public let updatedAt: Date

    public init(
        batchJobID: UUID,
        status: BatchJobStatus,
        progress: BatchJobProgress,
        failedItemIDs: [UUID],
        cancelledItemIDs: [UUID],
        updatedAt: Date
    ) {
        self.batchJobID = batchJobID
        self.status = status
        self.progress = progress
        self.failedItemIDs = failedItemIDs
        self.cancelledItemIDs = cancelledItemIDs
        self.updatedAt = updatedAt
    }
}
