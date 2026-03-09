import Foundation

public struct TranscriptItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let sourceType: SubtitleSourceType
    public let languageCode: String
    public let format: TranscriptFormat
    public let content: String
    public let segments: [TranscriptSegment]
    public let artifacts: [TranscriptArtifact]
    public let backend: TranscriptionBackend?
    public let modelID: String?
    public let detectedLanguage: String?

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        sourceType: SubtitleSourceType,
        languageCode: String,
        format: TranscriptFormat,
        content: String,
        segments: [TranscriptSegment] = [],
        artifacts: [TranscriptArtifact] = [],
        backend: TranscriptionBackend? = nil,
        modelID: String? = nil,
        detectedLanguage: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.sourceType = sourceType
        self.languageCode = languageCode
        self.format = format
        self.content = content
        self.segments = segments
        self.artifacts = artifacts
        self.backend = backend
        self.modelID = modelID
        self.detectedLanguage = detectedLanguage
    }
}

public struct SummaryRequest: Codable, Hashable, Sendable {
    public let provider: ProviderType
    public let modelID: String
    public let mode: SummaryMode
    public let length: SummaryLength
    public let outputLanguage: String
    public let prompt: String
    public let templateKind: SummaryPromptTemplateKind
    public let customPromptOverride: String?
    public let chunkingStrategy: SummaryChunkingStrategy
    public let structuredOutputPreferred: Bool
    public let outputFormat: SummaryOutputFormat
    public let debugDiagnosticsEnabled: Bool

    public init(
        provider: ProviderType,
        modelID: String,
        mode: SummaryMode,
        length: SummaryLength,
        outputLanguage: String,
        prompt: String,
        templateKind: SummaryPromptTemplateKind = .general,
        customPromptOverride: String? = nil,
        chunkingStrategy: SummaryChunkingStrategy = .segmentAware,
        structuredOutputPreferred: Bool = true,
        outputFormat: SummaryOutputFormat = .markdown,
        debugDiagnosticsEnabled: Bool = false
    ) {
        self.provider = provider
        self.modelID = modelID
        self.mode = mode
        self.length = length
        self.outputLanguage = outputLanguage
        self.prompt = prompt
        self.templateKind = templateKind
        self.customPromptOverride = customPromptOverride
        self.chunkingStrategy = chunkingStrategy
        self.structuredOutputPreferred = structuredOutputPreferred
        self.outputFormat = outputFormat
        self.debugDiagnosticsEnabled = debugDiagnosticsEnabled
    }
}

public struct SummaryResult: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let provider: ProviderType
    public let modelID: String
    public let mode: SummaryMode
    public let length: SummaryLength
    public let content: String
    public let structured: StructuredSummaryPayload?
    public let markdown: String?
    public let plainText: String?
    public let artifacts: [SummaryArtifact]
    public let templateKind: SummaryPromptTemplateKind?
    public let outputLanguage: String?
    public let diagnostics: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        provider: ProviderType,
        modelID: String,
        mode: SummaryMode,
        length: SummaryLength,
        content: String,
        structured: StructuredSummaryPayload? = nil,
        markdown: String? = nil,
        plainText: String? = nil,
        artifacts: [SummaryArtifact] = [],
        templateKind: SummaryPromptTemplateKind? = nil,
        outputLanguage: String? = nil,
        diagnostics: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.provider = provider
        self.modelID = modelID
        self.mode = mode
        self.length = length
        self.content = content
        self.structured = structured
        self.markdown = markdown
        self.plainText = plainText
        self.artifacts = artifacts
        self.templateKind = templateKind
        self.outputLanguage = outputLanguage
        self.diagnostics = diagnostics
        self.createdAt = createdAt
    }
}
