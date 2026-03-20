import Foundation

public struct DefaultPreferences: Codable, Hashable, Sendable {
    public var subtitleLanguage: String
    public var summaryLanguage: String
    public var summaryProvider: ProviderType
    public var summaryModelID: String
    public var summaryTemplateKind: SummaryPromptTemplateKind
    public var summaryMode: SummaryMode
    public var summaryLength: SummaryLength
    public var summaryOutputFormat: SummaryOutputFormat
    public var summaryChunkingStrategy: SummaryChunkingStrategy
    public var summaryStructuredOutputPreferred: Bool
    public var videoQuality: String
    public var exportDirectory: String
    public var resumeDownloadsEnabled: Bool
    public var overwritePolicy: FileOverwritePolicy
    public var transcriptionBackend: TranscriptionBackend
    public var openAITranscriptionModel: String
    public var whisperExecutablePath: String
    public var whisperModelPath: String
    public var transcriptOutputFormats: [TranscriptOutputKind]
    public var transcriptionPreprocessingEnabled: Bool
    public var transcriptionLanguageHint: String

    public init(
        subtitleLanguage: String = "en",
        summaryLanguage: String = "en",
        summaryProvider: ProviderType = .openAI,
        summaryModelID: String = "gpt-4.1-mini",
        summaryTemplateKind: SummaryPromptTemplateKind = .general,
        summaryMode: SummaryMode = .abstractSummary,
        summaryLength: SummaryLength = .medium,
        summaryOutputFormat: SummaryOutputFormat = .markdown,
        summaryChunkingStrategy: SummaryChunkingStrategy = .segmentAware,
        summaryStructuredOutputPreferred: Bool = true,
        videoQuality: String = "720p",
        exportDirectory: String = "~/Downloads/VideoWorkspace",
        resumeDownloadsEnabled: Bool = true,
        overwritePolicy: FileOverwritePolicy = .renameIfNeeded,
        transcriptionBackend: TranscriptionBackend = .whisperCPP,
        openAITranscriptionModel: String = "gpt-4o-mini-transcribe",
        whisperExecutablePath: String = "",
        whisperModelPath: String = "",
        transcriptOutputFormats: [TranscriptOutputKind] = [.txt, .srt, .vtt],
        transcriptionPreprocessingEnabled: Bool = true,
        transcriptionLanguageHint: String = "en"
    ) {
        self.subtitleLanguage = subtitleLanguage
        self.summaryLanguage = summaryLanguage
        self.summaryProvider = summaryProvider
        self.summaryModelID = summaryModelID
        self.summaryTemplateKind = summaryTemplateKind
        self.summaryMode = summaryMode
        self.summaryLength = summaryLength
        self.summaryOutputFormat = summaryOutputFormat
        self.summaryChunkingStrategy = summaryChunkingStrategy
        self.summaryStructuredOutputPreferred = summaryStructuredOutputPreferred
        self.videoQuality = videoQuality
        self.exportDirectory = exportDirectory
        self.resumeDownloadsEnabled = resumeDownloadsEnabled
        self.overwritePolicy = overwritePolicy
        self.transcriptionBackend = transcriptionBackend
        self.openAITranscriptionModel = openAITranscriptionModel
        self.whisperExecutablePath = whisperExecutablePath
        self.whisperModelPath = whisperModelPath
        self.transcriptOutputFormats = transcriptOutputFormats
        self.transcriptionPreprocessingEnabled = transcriptionPreprocessingEnabled
        self.transcriptionLanguageHint = transcriptionLanguageHint
    }
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var themeMode: ThemeMode
    public var proxyMode: ProxyMode
    public var customProxyAddress: String
    public var simpleModeEnabled: Bool
    public var onboardingCompleted: Bool
    public var defaults: DefaultPreferences
    public var retentionPolicy: ArtifactRetentionPolicy

    public init(
        themeMode: ThemeMode = .system,
        proxyMode: ProxyMode = .system,
        customProxyAddress: String = "",
        simpleModeEnabled: Bool = true,
        onboardingCompleted: Bool = false,
        defaults: DefaultPreferences = DefaultPreferences(),
        retentionPolicy: ArtifactRetentionPolicy = .default
    ) {
        self.themeMode = themeMode
        self.proxyMode = proxyMode
        self.customProxyAddress = customProxyAddress
        self.simpleModeEnabled = simpleModeEnabled
        self.onboardingCompleted = onboardingCompleted
        self.defaults = defaults
        self.retentionPolicy = retentionPolicy
    }

    // Forward-compatible decoder: missing fields fall back to defaults so
    // existing databases (written before new fields were added) still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings()
        themeMode            = (try? c.decodeIfPresent(ThemeMode.self,              forKey: .themeMode))            ?? fallback.themeMode
        proxyMode            = (try? c.decodeIfPresent(ProxyMode.self,              forKey: .proxyMode))            ?? fallback.proxyMode
        customProxyAddress   = (try? c.decodeIfPresent(String.self,                 forKey: .customProxyAddress))   ?? fallback.customProxyAddress
        simpleModeEnabled    = (try? c.decodeIfPresent(Bool.self,                   forKey: .simpleModeEnabled))    ?? fallback.simpleModeEnabled
        onboardingCompleted  = (try? c.decodeIfPresent(Bool.self,                   forKey: .onboardingCompleted))  ?? fallback.onboardingCompleted
        defaults             = (try? c.decodeIfPresent(DefaultPreferences.self,     forKey: .defaults))             ?? fallback.defaults
        retentionPolicy      = (try? c.decodeIfPresent(ArtifactRetentionPolicy.self, forKey: .retentionPolicy))     ?? fallback.retentionPolicy
    }
}
