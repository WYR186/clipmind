import Foundation

public struct TranslationResult: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let sourceTranscriptID: UUID?
    public let provider: ProviderType
    public let modelID: String
    public let languagePair: TranslationLanguagePair
    public let mode: TranslationMode
    public let style: TranslationStyle
    public let translatedText: String
    public let bilingualText: String?
    public let segments: [TranslationSegment]
    public let artifacts: [TranslationArtifact]
    public let diagnostics: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        sourceTranscriptID: UUID? = nil,
        provider: ProviderType,
        modelID: String,
        languagePair: TranslationLanguagePair,
        mode: TranslationMode,
        style: TranslationStyle,
        translatedText: String,
        bilingualText: String? = nil,
        segments: [TranslationSegment] = [],
        artifacts: [TranslationArtifact] = [],
        diagnostics: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.sourceTranscriptID = sourceTranscriptID
        self.provider = provider
        self.modelID = modelID
        self.languagePair = languagePair
        self.mode = mode
        self.style = style
        self.translatedText = translatedText
        self.bilingualText = bilingualText
        self.segments = segments
        self.artifacts = artifacts
        self.diagnostics = diagnostics
        self.createdAt = createdAt
    }
}
