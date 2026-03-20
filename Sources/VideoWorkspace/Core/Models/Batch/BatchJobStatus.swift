import Foundation

public enum BatchJobStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case paused
    case completed
    case completedWithFailures
    case failed
    case cancelled
    case interrupted

    public var isTerminal: Bool {
        switch self {
        case .completed, .completedWithFailures, .failed, .cancelled, .interrupted:
            return true
        case .queued, .running, .paused:
            return false
        }
    }

    public var isActive: Bool {
        self == .running || self == .paused
    }
}

public enum BatchJobItemStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case running
    case completed
    case failed
    case skipped
    case cancelled
    case interrupted

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .skipped, .cancelled, .interrupted:
            return true
        case .pending, .running:
            return false
        }
    }
}

public enum BatchSourceType: String, Codable, CaseIterable, Sendable {
    case urlBatch
    case localFilesBatch
    case mixed
}

public enum BatchOperationType: String, Codable, CaseIterable, Sendable {
    case copyTranscript
    case transcribe
    case summarize
    case translate
    case exportAudio
    case exportVideo
    case exportSubtitle

    public var defaultTaskType: TaskType {
        switch self {
        case .copyTranscript:
            return .copyTranscript
        case .transcribe:
            return .transcribe
        case .summarize:
            return .summarize
        case .translate:
            return .translate
        case .exportAudio, .exportVideo, .exportSubtitle:
            return .export
        }
    }
}
