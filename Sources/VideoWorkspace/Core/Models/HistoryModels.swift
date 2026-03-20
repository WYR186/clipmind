import Foundation

public struct HistoryEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let taskID: UUID?
    public let source: MediaSource
    public let taskType: TaskType
    public let transcript: TranscriptItem?
    public let summary: SummaryResult?
    public let translation: TranslationResult?
    public let downloadResult: MediaDownloadResult?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        source: MediaSource,
        taskType: TaskType,
        transcript: TranscriptItem?,
        summary: SummaryResult?,
        translation: TranslationResult? = nil,
        downloadResult: MediaDownloadResult? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.source = source
        self.taskType = taskType
        self.transcript = transcript
        self.summary = summary
        self.translation = translation
        self.downloadResult = downloadResult
        self.createdAt = createdAt
    }
}
