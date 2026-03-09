import Foundation

public enum DownloadKind: String, Codable, CaseIterable, Sendable {
    case subtitle
    case audioOnly
    case video
}

public enum FileOverwritePolicy: String, Codable, CaseIterable, Sendable {
    case renameIfNeeded
    case replace
    case skip
}

public enum SubtitleExportFormat: String, Codable, CaseIterable, Sendable {
    case vtt
    case srt
}

public struct MediaDownloadRequest: Sendable {
    public let source: MediaSource
    public let kind: DownloadKind
    public let metadataTitle: String?
    public let selectedVideoFormatID: String?
    public let selectedAudioFormatID: String?
    public let selectedSubtitleTrack: SubtitleTrack?
    public let outputDirectory: String?
    public let preferredFileName: String?
    public let resumeEnabled: Bool
    public let overwritePolicy: FileOverwritePolicy
    public let preferredSubtitleFormat: SubtitleExportFormat?

    public init(
        source: MediaSource,
        kind: DownloadKind,
        metadataTitle: String? = nil,
        selectedVideoFormatID: String? = nil,
        selectedAudioFormatID: String? = nil,
        selectedSubtitleTrack: SubtitleTrack? = nil,
        outputDirectory: String? = nil,
        preferredFileName: String? = nil,
        resumeEnabled: Bool = true,
        overwritePolicy: FileOverwritePolicy = .renameIfNeeded,
        preferredSubtitleFormat: SubtitleExportFormat? = nil
    ) {
        self.source = source
        self.kind = kind
        self.metadataTitle = metadataTitle
        self.selectedVideoFormatID = selectedVideoFormatID
        self.selectedAudioFormatID = selectedAudioFormatID
        self.selectedSubtitleTrack = selectedSubtitleTrack
        self.outputDirectory = outputDirectory
        self.preferredFileName = preferredFileName
        self.resumeEnabled = resumeEnabled
        self.overwritePolicy = overwritePolicy
        self.preferredSubtitleFormat = preferredSubtitleFormat
    }

    // Compatibility initializer for existing mock/transcription flow.
    public init(source: MediaSource, preferAudioOnly: Bool, subtitleLanguage: String?) {
        self.init(
            source: source,
            kind: preferAudioOnly ? .audioOnly : .video,
            metadataTitle: nil,
            selectedVideoFormatID: nil,
            selectedAudioFormatID: nil,
            selectedSubtitleTrack: subtitleLanguage.map {
                SubtitleTrack(languageCode: $0, languageName: $0, sourceType: .native)
            },
            outputDirectory: nil,
            preferredFileName: nil,
            resumeEnabled: true,
            overwritePolicy: .renameIfNeeded,
            preferredSubtitleFormat: nil
        )
    }
}

public struct MediaDownloadResult: Codable, Hashable, Sendable {
    public let kind: DownloadKind
    public let outputPath: String
    public let outputFileName: String
    public let usedVideoFormatID: String?
    public let usedAudioFormatID: String?
    public let subtitleLanguage: String?

    public init(
        kind: DownloadKind,
        outputPath: String,
        outputFileName: String,
        usedVideoFormatID: String? = nil,
        usedAudioFormatID: String? = nil,
        subtitleLanguage: String? = nil
    ) {
        self.kind = kind
        self.outputPath = outputPath
        self.outputFileName = outputFileName
        self.usedVideoFormatID = usedVideoFormatID
        self.usedAudioFormatID = usedAudioFormatID
        self.subtitleLanguage = subtitleLanguage
    }

    public var localPath: String {
        outputPath
    }
}
