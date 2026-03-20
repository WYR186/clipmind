import Foundation

public struct BatchOperationTemplate: Codable, Hashable, Sendable {
    public let operationType: BatchOperationType
    public let outputLanguage: String
    public let summaryMode: SummaryMode
    public let summaryLength: SummaryLength
    public let provider: ProviderType
    public let modelID: String
    public let summaryTemplateKind: SummaryPromptTemplateKind
    public let outputDirectory: String?
    public let transcriptionBackend: TranscriptionBackend
    public let openAITranscriptionModel: String
    public let whisperExecutablePath: String?
    public let whisperModelPath: String?
    public let transcriptionLanguageHint: String?
    public let transcriptOutputKinds: [TranscriptOutputKind]
    public let overwritePolicy: FileOverwritePolicy
    public let resumeDownloadsEnabled: Bool
    public let summaryChunkingStrategy: SummaryChunkingStrategy
    public let summaryStructuredOutputPreferred: Bool
    public let summaryOutputFormat: SummaryOutputFormat
    public let translationTargetLanguage: String
    public let translationMode: TranslationMode
    public let translationStyle: TranslationStyle
    public let translationBilingualOutputEnabled: Bool
    public let translationPreserveTimestamps: Bool
    public let translationPreserveTerminology: Bool
    public let translationOutputFormats: [TranslationOutputFormat]
    public let maxConcurrentItems: Int

    enum CodingKeys: String, CodingKey {
        case operationType
        case outputLanguage
        case summaryMode
        case summaryLength
        case provider
        case modelID
        case summaryTemplateKind
        case outputDirectory
        case transcriptionBackend
        case openAITranscriptionModel
        case whisperExecutablePath
        case whisperModelPath
        case transcriptionLanguageHint
        case transcriptOutputKinds
        case overwritePolicy
        case resumeDownloadsEnabled
        case summaryChunkingStrategy
        case summaryStructuredOutputPreferred
        case summaryOutputFormat
        case translationTargetLanguage
        case translationMode
        case translationStyle
        case translationBilingualOutputEnabled
        case translationPreserveTimestamps
        case translationPreserveTerminology
        case translationOutputFormats
        case maxConcurrentItems
    }

    public init(
        operationType: BatchOperationType,
        outputLanguage: String,
        summaryMode: SummaryMode,
        summaryLength: SummaryLength,
        provider: ProviderType,
        modelID: String,
        summaryTemplateKind: SummaryPromptTemplateKind,
        outputDirectory: String?,
        transcriptionBackend: TranscriptionBackend,
        openAITranscriptionModel: String,
        whisperExecutablePath: String?,
        whisperModelPath: String?,
        transcriptionLanguageHint: String?,
        transcriptOutputKinds: [TranscriptOutputKind],
        overwritePolicy: FileOverwritePolicy,
        resumeDownloadsEnabled: Bool,
        summaryChunkingStrategy: SummaryChunkingStrategy,
        summaryStructuredOutputPreferred: Bool,
        summaryOutputFormat: SummaryOutputFormat,
        translationTargetLanguage: String = "en",
        translationMode: TranslationMode = .plain,
        translationStyle: TranslationStyle = .faithful,
        translationBilingualOutputEnabled: Bool = false,
        translationPreserveTimestamps: Bool = true,
        translationPreserveTerminology: Bool = true,
        translationOutputFormats: [TranslationOutputFormat] = [.txt],
        maxConcurrentItems: Int = 2
    ) {
        self.operationType = operationType
        self.outputLanguage = outputLanguage
        self.summaryMode = summaryMode
        self.summaryLength = summaryLength
        self.provider = provider
        self.modelID = modelID
        self.summaryTemplateKind = summaryTemplateKind
        self.outputDirectory = outputDirectory
        self.transcriptionBackend = transcriptionBackend
        self.openAITranscriptionModel = openAITranscriptionModel
        self.whisperExecutablePath = whisperExecutablePath
        self.whisperModelPath = whisperModelPath
        self.transcriptionLanguageHint = transcriptionLanguageHint
        self.transcriptOutputKinds = transcriptOutputKinds.isEmpty ? [.txt] : transcriptOutputKinds
        self.overwritePolicy = overwritePolicy
        self.resumeDownloadsEnabled = resumeDownloadsEnabled
        self.summaryChunkingStrategy = summaryChunkingStrategy
        self.summaryStructuredOutputPreferred = summaryStructuredOutputPreferred
        self.summaryOutputFormat = summaryOutputFormat
        self.translationTargetLanguage = translationTargetLanguage
        self.translationMode = translationMode
        self.translationStyle = translationStyle
        self.translationBilingualOutputEnabled = translationBilingualOutputEnabled
        self.translationPreserveTimestamps = translationPreserveTimestamps
        self.translationPreserveTerminology = translationPreserveTerminology
        self.translationOutputFormats = translationOutputFormats.isEmpty ? [.txt] : translationOutputFormats
        self.maxConcurrentItems = max(1, maxConcurrentItems)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.operationType = try container.decode(BatchOperationType.self, forKey: .operationType)
        self.outputLanguage = try container.decode(String.self, forKey: .outputLanguage)
        self.summaryMode = try container.decode(SummaryMode.self, forKey: .summaryMode)
        self.summaryLength = try container.decode(SummaryLength.self, forKey: .summaryLength)
        self.provider = try container.decode(ProviderType.self, forKey: .provider)
        self.modelID = try container.decode(String.self, forKey: .modelID)
        self.summaryTemplateKind = try container.decode(SummaryPromptTemplateKind.self, forKey: .summaryTemplateKind)
        self.outputDirectory = try container.decodeIfPresent(String.self, forKey: .outputDirectory)
        self.transcriptionBackend = try container.decode(TranscriptionBackend.self, forKey: .transcriptionBackend)
        self.openAITranscriptionModel = try container.decode(String.self, forKey: .openAITranscriptionModel)
        self.whisperExecutablePath = try container.decodeIfPresent(String.self, forKey: .whisperExecutablePath)
        self.whisperModelPath = try container.decodeIfPresent(String.self, forKey: .whisperModelPath)
        self.transcriptionLanguageHint = try container.decodeIfPresent(String.self, forKey: .transcriptionLanguageHint)
        self.transcriptOutputKinds = try container.decode([TranscriptOutputKind].self, forKey: .transcriptOutputKinds)
        self.overwritePolicy = try container.decode(FileOverwritePolicy.self, forKey: .overwritePolicy)
        self.resumeDownloadsEnabled = try container.decode(Bool.self, forKey: .resumeDownloadsEnabled)
        self.summaryChunkingStrategy = try container.decode(SummaryChunkingStrategy.self, forKey: .summaryChunkingStrategy)
        self.summaryStructuredOutputPreferred = try container.decode(Bool.self, forKey: .summaryStructuredOutputPreferred)
        self.summaryOutputFormat = try container.decode(SummaryOutputFormat.self, forKey: .summaryOutputFormat)
        self.translationTargetLanguage = try container.decodeIfPresent(String.self, forKey: .translationTargetLanguage) ?? outputLanguage
        self.translationMode = try container.decodeIfPresent(TranslationMode.self, forKey: .translationMode) ?? .plain
        self.translationStyle = try container.decodeIfPresent(TranslationStyle.self, forKey: .translationStyle) ?? .faithful
        self.translationBilingualOutputEnabled = try container.decodeIfPresent(Bool.self, forKey: .translationBilingualOutputEnabled) ?? false
        self.translationPreserveTimestamps = try container.decodeIfPresent(Bool.self, forKey: .translationPreserveTimestamps) ?? true
        self.translationPreserveTerminology = try container.decodeIfPresent(Bool.self, forKey: .translationPreserveTerminology) ?? true
        self.translationOutputFormats = try container.decodeIfPresent([TranslationOutputFormat].self, forKey: .translationOutputFormats) ?? [.txt]
        self.maxConcurrentItems = max(1, try container.decode(Int.self, forKey: .maxConcurrentItems))
    }
}

public extension BatchOperationTemplate {
    static func fromDefaults(
        operationType: BatchOperationType,
        defaults: DefaultPreferences,
        maxConcurrentItems: Int = 2
    ) -> BatchOperationTemplate {
        BatchOperationTemplate(
            operationType: operationType,
            outputLanguage: defaults.summaryLanguage,
            summaryMode: defaults.summaryMode,
            summaryLength: defaults.summaryLength,
            provider: defaults.summaryProvider,
            modelID: defaults.summaryModelID,
            summaryTemplateKind: defaults.summaryTemplateKind,
            outputDirectory: defaults.exportDirectory,
            transcriptionBackend: defaults.transcriptionBackend,
            openAITranscriptionModel: defaults.openAITranscriptionModel,
            whisperExecutablePath: defaults.whisperExecutablePath,
            whisperModelPath: defaults.whisperModelPath,
            transcriptionLanguageHint: defaults.transcriptionLanguageHint,
            transcriptOutputKinds: defaults.transcriptOutputFormats,
            overwritePolicy: defaults.overwritePolicy,
            resumeDownloadsEnabled: defaults.resumeDownloadsEnabled,
            summaryChunkingStrategy: defaults.summaryChunkingStrategy,
            summaryStructuredOutputPreferred: defaults.summaryStructuredOutputPreferred,
            summaryOutputFormat: defaults.summaryOutputFormat,
            translationTargetLanguage: defaults.summaryLanguage,
            translationMode: .plain,
            translationStyle: .faithful,
            translationBilingualOutputEnabled: false,
            translationPreserveTimestamps: true,
            translationPreserveTerminology: true,
            translationOutputFormats: [.txt],
            maxConcurrentItems: maxConcurrentItems
        )
    }
}
