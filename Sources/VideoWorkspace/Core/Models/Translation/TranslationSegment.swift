import Foundation

public struct TranslationSegment: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let index: Int
    public let startSeconds: Double?
    public let endSeconds: Double?
    public let sourceText: String
    public let translatedText: String

    public init(
        id: UUID = UUID(),
        index: Int,
        startSeconds: Double? = nil,
        endSeconds: Double? = nil,
        sourceText: String,
        translatedText: String
    ) {
        self.id = id
        self.index = index
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.sourceText = sourceText
        self.translatedText = translatedText
    }
}

public enum TranslationOutputFormat: String, Codable, CaseIterable, Sendable {
    case txt
    case srt
    case vtt
    case markdown
}

public struct TranslationArtifact: Codable, Hashable, Sendable {
    public let format: TranslationOutputFormat
    public let path: String

    public init(format: TranslationOutputFormat, path: String) {
        self.format = format
        self.path = path
    }
}
