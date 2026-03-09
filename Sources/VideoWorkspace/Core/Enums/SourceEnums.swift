import Foundation

public enum SourceType: String, Codable, CaseIterable, Sendable {
    case url
    case localFile
}

public enum SubtitleSourceType: String, Codable, CaseIterable, Sendable {
    case native
    case auto
    case asr
}
