import Foundation

public enum TranscriptionBackend: String, Codable, CaseIterable, Sendable {
    case openAI
    case whisperCPP
}

public enum TranscriptOutputKind: String, Codable, CaseIterable, Sendable {
    case txt
    case srt
    case vtt
}

public struct TranscriptSegment: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let index: Int
    public let startSeconds: Double
    public let endSeconds: Double
    public let text: String

    public init(
        id: UUID = UUID(),
        index: Int,
        startSeconds: Double,
        endSeconds: Double,
        text: String
    ) {
        self.id = id
        self.index = index
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
    }
}

public struct TranscriptArtifact: Codable, Hashable, Sendable {
    public let kind: TranscriptOutputKind
    public let path: String

    public init(kind: TranscriptOutputKind, path: String) {
        self.kind = kind
        self.path = path
    }
}

public struct TranscriptionRequest: Sendable {
    public let taskID: UUID
    public let sourcePath: String
    public let sourceType: SourceType
    public let backend: TranscriptionBackend
    public let modelIdentifier: String
    public let outputKinds: [TranscriptOutputKind]
    public let languageHint: String?
    public let promptHint: String?
    public let temperature: Double?
    public let outputDirectory: String?
    public let overwritePolicy: FileOverwritePolicy
    public let preprocessingRequired: Bool
    public let debugDiagnosticsEnabled: Bool
    public let whisperExecutablePath: String?
    public let whisperModelPath: String?
    public let useOpenAITimestampGranularity: Bool

    public init(
        taskID: UUID,
        sourcePath: String,
        sourceType: SourceType,
        backend: TranscriptionBackend,
        modelIdentifier: String,
        outputKinds: [TranscriptOutputKind],
        languageHint: String? = nil,
        promptHint: String? = nil,
        temperature: Double? = nil,
        outputDirectory: String? = nil,
        overwritePolicy: FileOverwritePolicy = .renameIfNeeded,
        preprocessingRequired: Bool = true,
        debugDiagnosticsEnabled: Bool = false,
        whisperExecutablePath: String? = nil,
        whisperModelPath: String? = nil,
        useOpenAITimestampGranularity: Bool = true
    ) {
        self.taskID = taskID
        self.sourcePath = sourcePath
        self.sourceType = sourceType
        self.backend = backend
        self.modelIdentifier = modelIdentifier
        self.outputKinds = outputKinds
        self.languageHint = languageHint
        self.promptHint = promptHint
        self.temperature = temperature
        self.outputDirectory = outputDirectory
        self.overwritePolicy = overwritePolicy
        self.preprocessingRequired = preprocessingRequired
        self.debugDiagnosticsEnabled = debugDiagnosticsEnabled
        self.whisperExecutablePath = whisperExecutablePath
        self.whisperModelPath = whisperModelPath
        self.useOpenAITimestampGranularity = useOpenAITimestampGranularity
    }
}

public struct TranscriptionResult: Sendable {
    public let transcript: TranscriptItem
    public let artifacts: [TranscriptArtifact]
    public let backendUsed: TranscriptionBackend
    public let modelUsed: String
    public let detectedLanguage: String?
    public let durationSeconds: Double?
    public let diagnostics: String?

    public init(
        transcript: TranscriptItem,
        artifacts: [TranscriptArtifact],
        backendUsed: TranscriptionBackend,
        modelUsed: String,
        detectedLanguage: String?,
        durationSeconds: Double?,
        diagnostics: String?
    ) {
        self.transcript = transcript
        self.artifacts = artifacts
        self.backendUsed = backendUsed
        self.modelUsed = modelUsed
        self.detectedLanguage = detectedLanguage
        self.durationSeconds = durationSeconds
        self.diagnostics = diagnostics
    }
}
