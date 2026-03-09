import Foundation

public enum TaskType: String, Codable, CaseIterable, Sendable {
    case inspect
    case copyTranscript
    case transcribe
    case summarize
    case export
}

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case completed
    case failed
    case canceled
}
