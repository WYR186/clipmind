import Foundation

public typealias BatchJobID = UUID

public struct BatchJob: Identifiable, Codable, Hashable, Sendable {
    public let id: BatchJobID
    public var title: String
    public var sourceType: BatchSourceType
    public let createdAt: Date
    public var updatedAt: Date
    public var status: BatchJobStatus
    public var progress: BatchJobProgress
    public var operationTemplate: BatchOperationTemplate
    public var childTaskIDs: [UUID]
    public var lastErrorSummary: String?
    public var sourceDescriptor: String?
    public var sourceMetadataJSON: String?

    public init(
        id: BatchJobID = UUID(),
        title: String,
        sourceType: BatchSourceType,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: BatchJobStatus = .queued,
        progress: BatchJobProgress,
        operationTemplate: BatchOperationTemplate,
        childTaskIDs: [UUID] = [],
        lastErrorSummary: String? = nil,
        sourceDescriptor: String? = nil,
        sourceMetadataJSON: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceType = sourceType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.progress = progress
        self.operationTemplate = operationTemplate
        self.childTaskIDs = childTaskIDs
        self.lastErrorSummary = lastErrorSummary
        self.sourceDescriptor = sourceDescriptor
        self.sourceMetadataJSON = sourceMetadataJSON
    }

    public var totalCount: Int { progress.totalCount }
    public var completedCount: Int { progress.completedCount }
    public var failedCount: Int { progress.failedCount }
    public var runningCount: Int { progress.runningCount }
    public var pendingCount: Int { progress.pendingCount }
    public var cancelledCount: Int { progress.cancelledCount }
}
