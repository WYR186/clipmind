import Foundation

public struct TaskProgress: Codable, Hashable, Sendable {
    public let fractionCompleted: Double
    public let currentStep: String

    public init(fractionCompleted: Double, currentStep: String) {
        self.fractionCompleted = max(0, min(fractionCompleted, 1))
        self.currentStep = currentStep
    }
}

public struct TaskError: Codable, Hashable, Sendable {
    public let code: String
    public let message: String
    public let technicalDetails: String?

    public init(code: String, message: String, technicalDetails: String? = nil) {
        self.code = code
        self.message = message
        self.technicalDetails = technicalDetails
    }
}

public struct TaskItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let source: MediaSource
    public let taskType: TaskType
    public var status: TaskStatus
    public var progress: TaskProgress
    public let createdAt: Date
    public var updatedAt: Date
    public var outputPath: String?
    public var error: TaskError?

    public init(
        id: UUID = UUID(),
        source: MediaSource,
        taskType: TaskType,
        status: TaskStatus = .queued,
        progress: TaskProgress = TaskProgress(fractionCompleted: 0, currentStep: "Queued"),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        outputPath: String? = nil,
        error: TaskError? = nil
    ) {
        self.id = id
        self.source = source
        self.taskType = taskType
        self.status = status
        self.progress = progress
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.outputPath = outputPath
        self.error = error
    }
}
