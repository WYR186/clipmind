import Foundation

public struct VideoFormatOption: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let formatID: String?
    public let qualityLabel: String
    public let displayLabel: String
    public let container: String
    public let extensionName: String?
    public let videoCodec: String?
    public let audioCodec: String?
    public let resolution: String?
    public let width: Int?
    public let height: Int?
    public let fps: Double?
    public let bitrateKbps: Int?
    public let fileSizeBytes: Int64?
    public let hasHDR: Bool
    public let isVideoOnly: Bool
    public let isAudioOnly: Bool

    public init(
        id: UUID = UUID(),
        formatID: String? = nil,
        qualityLabel: String,
        displayLabel: String? = nil,
        container: String,
        extensionName: String? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        resolution: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        fps: Double? = nil,
        bitrateKbps: Int? = nil,
        fileSizeBytes: Int64? = nil,
        hasHDR: Bool = false,
        isVideoOnly: Bool = false,
        isAudioOnly: Bool = false
    ) {
        self.id = id
        self.formatID = formatID
        self.qualityLabel = qualityLabel
        self.displayLabel = displayLabel ?? qualityLabel
        self.container = container
        self.extensionName = extensionName
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.resolution = resolution
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrateKbps = bitrateKbps
        self.fileSizeBytes = fileSizeBytes
        self.hasHDR = hasHDR
        self.isVideoOnly = isVideoOnly
        self.isAudioOnly = isAudioOnly
    }
}

public struct AudioFormatOption: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let formatID: String?
    public let extensionName: String?
    public let codec: String
    public let bitrateKbps: Int
    public let sampleRateHz: Int?
    public let channels: Int?
    public let fileSizeBytes: Int64?
    public let displayLabel: String

    public init(
        id: UUID = UUID(),
        formatID: String? = nil,
        extensionName: String? = nil,
        codec: String,
        bitrateKbps: Int,
        sampleRateHz: Int? = nil,
        channels: Int? = nil,
        fileSizeBytes: Int64? = nil,
        displayLabel: String? = nil
    ) {
        self.id = id
        self.formatID = formatID
        self.extensionName = extensionName
        self.codec = codec
        self.bitrateKbps = bitrateKbps
        self.sampleRateHz = sampleRateHz
        self.channels = channels
        self.fileSizeBytes = fileSizeBytes
        self.displayLabel = displayLabel ?? "\(codec) \(bitrateKbps) kbps"
    }
}

public struct SubtitleTrack: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let languageCode: String
    public let languageName: String
    public let sourceType: SubtitleSourceType
    public let extensionName: String?
    public let remoteURL: String?
    public let displayLabel: String

    public init(
        id: UUID = UUID(),
        languageCode: String,
        languageName: String,
        sourceType: SubtitleSourceType,
        extensionName: String? = nil,
        remoteURL: String? = nil,
        displayLabel: String? = nil
    ) {
        self.id = id
        self.languageCode = languageCode
        self.languageName = languageName
        self.sourceType = sourceType
        self.extensionName = extensionName
        self.remoteURL = remoteURL
        self.displayLabel = displayLabel ?? "\(languageName) (\(sourceType.rawValue))"
    }
}

public struct MediaMetadata: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let source: MediaSource
    public let title: String
    public let durationSeconds: Int
    public let thumbnailURL: String?
    public let platform: String?
    public let webpageURL: String?
    public let container: String?
    public let bitrateKbps: Int?
    public let fileSizeBytes: Int64?
    public let videoOptions: [VideoFormatOption]
    public let audioOptions: [AudioFormatOption]
    public let subtitleTracks: [SubtitleTrack]

    public init(
        id: UUID = UUID(),
        source: MediaSource,
        title: String,
        durationSeconds: Int,
        thumbnailURL: String?,
        platform: String? = nil,
        webpageURL: String? = nil,
        container: String? = nil,
        bitrateKbps: Int? = nil,
        fileSizeBytes: Int64? = nil,
        videoOptions: [VideoFormatOption],
        audioOptions: [AudioFormatOption],
        subtitleTracks: [SubtitleTrack]
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.durationSeconds = durationSeconds
        self.thumbnailURL = thumbnailURL
        self.platform = platform
        self.webpageURL = webpageURL
        self.container = container
        self.bitrateKbps = bitrateKbps
        self.fileSizeBytes = fileSizeBytes
        self.videoOptions = videoOptions
        self.audioOptions = audioOptions
        self.subtitleTracks = subtitleTracks
    }
}
