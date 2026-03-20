import Foundation

public struct BatchJobProgress: Codable, Hashable, Sendable {
    public let totalCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let runningCount: Int
    public let pendingCount: Int
    public let cancelledCount: Int
    public let fractionCompleted: Double

    public init(
        totalCount: Int,
        completedCount: Int,
        failedCount: Int,
        runningCount: Int,
        pendingCount: Int,
        cancelledCount: Int,
        fractionCompleted: Double
    ) {
        self.totalCount = max(0, totalCount)
        self.completedCount = max(0, completedCount)
        self.failedCount = max(0, failedCount)
        self.runningCount = max(0, runningCount)
        self.pendingCount = max(0, pendingCount)
        self.cancelledCount = max(0, cancelledCount)
        self.fractionCompleted = max(0, min(1, fractionCompleted))
    }

    public static var empty: BatchJobProgress {
        BatchJobProgress(
            totalCount: 0,
            completedCount: 0,
            failedCount: 0,
            runningCount: 0,
            pendingCount: 0,
            cancelledCount: 0,
            fractionCompleted: 0
        )
    }

    public var terminalCount: Int {
        completedCount + failedCount + cancelledCount
    }
}
