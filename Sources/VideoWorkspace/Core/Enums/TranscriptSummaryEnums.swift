import Foundation

public enum TranscriptFormat: String, Codable, CaseIterable, Sendable {
    case txt
    case srt
    case vtt
}

public enum SummaryMode: String, Codable, CaseIterable, Sendable {
    case abstractSummary = "summary"
    case keyPoints
    case chapters
}

public enum SummaryLength: String, Codable, CaseIterable, Sendable {
    case short
    case medium
    case long
}
