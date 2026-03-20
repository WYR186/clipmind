import Foundation

public enum ArtifactOwnerType: String, Codable, CaseIterable, Sendable {
    case task
    case history
    case transcript
    case summary
    case translation
    case download
}

public enum ArtifactType: String, Codable, CaseIterable, Sendable {
    case downloadVideo = "download_video"
    case downloadAudio = "download_audio"
    case downloadSubtitle = "download_subtitle"
    case transcriptTXT = "transcript_txt"
    case transcriptSRT = "transcript_srt"
    case transcriptVTT = "transcript_vtt"
    case summaryMarkdown = "summary_markdown"
    case summaryPlainText = "summary_plaintext"
    case summaryJSON = "summary_json"
    case translationTXT = "translation_txt"
    case translationSRT = "translation_srt"
    case translationVTT = "translation_vtt"
    case translationMarkdown = "translation_markdown"
    case localReference = "local_reference"
}

public struct ArtifactRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let ownerType: ArtifactOwnerType
    public let ownerID: UUID
    public let relatedTaskID: UUID?
    public let relatedHistoryID: UUID?
    public let artifactType: ArtifactType
    public let filePath: String
    public let fileFormat: String
    public let sizeBytes: Int64?
    public let backend: String?
    public let provider: ProviderType?
    public let model: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        ownerType: ArtifactOwnerType,
        ownerID: UUID,
        relatedTaskID: UUID? = nil,
        relatedHistoryID: UUID? = nil,
        artifactType: ArtifactType,
        filePath: String,
        fileFormat: String,
        sizeBytes: Int64? = nil,
        backend: String? = nil,
        provider: ProviderType? = nil,
        model: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownerType = ownerType
        self.ownerID = ownerID
        self.relatedTaskID = relatedTaskID
        self.relatedHistoryID = relatedHistoryID
        self.artifactType = artifactType
        self.filePath = filePath
        self.fileFormat = fileFormat
        self.sizeBytes = sizeBytes
        self.backend = backend
        self.provider = provider
        self.model = model
        self.createdAt = createdAt
    }
}
