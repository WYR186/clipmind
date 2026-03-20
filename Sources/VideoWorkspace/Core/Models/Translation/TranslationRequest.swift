import Foundation

public struct TranslationRequest: Sendable {
    public let taskID: UUID
    public let sourceTranscriptID: UUID?
    public let sourceText: String
    public let sourceSegments: [TranscriptSegment]
    public let sourceFormat: TranscriptFormat
    public let languagePair: TranslationLanguagePair
    public let provider: ProviderType
    public let modelID: String
    public let mode: TranslationMode
    public let style: TranslationStyle
    public let bilingualOutputEnabled: Bool
    public let preserveTimestamps: Bool
    public let preserveTerminology: Bool
    public let outputFormats: [TranslationOutputFormat]
    public let outputDirectory: String?
    public let overwritePolicy: FileOverwritePolicy
    public let debugDiagnosticsEnabled: Bool

    public init(
        taskID: UUID,
        sourceTranscriptID: UUID? = nil,
        sourceText: String,
        sourceSegments: [TranscriptSegment] = [],
        sourceFormat: TranscriptFormat = .txt,
        languagePair: TranslationLanguagePair,
        provider: ProviderType,
        modelID: String,
        mode: TranslationMode,
        style: TranslationStyle = .faithful,
        bilingualOutputEnabled: Bool,
        preserveTimestamps: Bool,
        preserveTerminology: Bool,
        outputFormats: [TranslationOutputFormat],
        outputDirectory: String? = nil,
        overwritePolicy: FileOverwritePolicy = .renameIfNeeded,
        debugDiagnosticsEnabled: Bool = false
    ) {
        self.taskID = taskID
        self.sourceTranscriptID = sourceTranscriptID
        self.sourceText = sourceText
        self.sourceSegments = sourceSegments
        self.sourceFormat = sourceFormat
        self.languagePair = languagePair
        self.provider = provider
        self.modelID = modelID
        self.mode = mode
        self.style = style
        self.bilingualOutputEnabled = bilingualOutputEnabled
        self.preserveTimestamps = preserveTimestamps
        self.preserveTerminology = preserveTerminology
        self.outputFormats = outputFormats
        self.outputDirectory = outputDirectory
        self.overwritePolicy = overwritePolicy
        self.debugDiagnosticsEnabled = debugDiagnosticsEnabled
    }
}
