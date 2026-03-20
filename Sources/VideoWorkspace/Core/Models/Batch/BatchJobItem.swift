import Foundation

public struct BatchJobItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let batchJobID: UUID
    public let source: MediaSource
    public var taskID: UUID?
    public var status: BatchJobItemStatus
    public var progress: Double
    public let createdAt: Date
    public var updatedAt: Date
    public var failureReason: String?
    public var errorCode: String?

    public init(
        id: UUID = UUID(),
        batchJobID: UUID,
        source: MediaSource,
        taskID: UUID? = nil,
        status: BatchJobItemStatus = .pending,
        progress: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        failureReason: String? = nil,
        errorCode: String? = nil
    ) {
        self.id = id
        self.batchJobID = batchJobID
        self.source = source
        self.taskID = taskID
        self.status = status
        self.progress = max(0, min(progress, 1))
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.failureReason = failureReason
        self.errorCode = errorCode
    }
}
