import Foundation

struct MockMediaInspectionService: MediaInspectionServiceProtocol {
    func inspect(source: MediaSource) async throws -> MediaMetadata {
        try await Task.sleep(nanoseconds: 450_000_000)

        let isOnline = source.type == .url
        return MediaMetadata(
            source: source,
            title: isOnline ? "Mock Course: Building Scalable Apps" : URL(fileURLWithPath: source.value).lastPathComponent,
            durationSeconds: isOnline ? 3_840 : 2_140,
            thumbnailURL: isOnline ? "https://img.youtube.com/vi/mock/hqdefault.jpg" : nil,
            platform: isOnline ? "YouTube" : "Local File",
            webpageURL: isOnline ? source.value : nil,
            container: isOnline ? "mp4" : "mov,mp4,m4a",
            bitrateKbps: isOnline ? nil : 2_400,
            fileSizeBytes: isOnline ? nil : 340_000_000,
            videoOptions: [
                VideoFormatOption(formatID: "18", qualityLabel: "360p", container: "mp4"),
                VideoFormatOption(formatID: "22", qualityLabel: "720p", container: "mp4"),
                VideoFormatOption(formatID: "137", qualityLabel: "1080p", container: "mp4")
            ],
            audioOptions: [
                AudioFormatOption(formatID: "140", extensionName: "m4a", codec: "aac", bitrateKbps: 128),
                AudioFormatOption(formatID: "251", extensionName: "webm", codec: "opus", bitrateKbps: 160)
            ],
            subtitleTracks: [
                SubtitleTrack(languageCode: "en", languageName: "English", sourceType: .native, extensionName: "vtt"),
                SubtitleTrack(languageCode: "zh", languageName: "Chinese", sourceType: .auto, extensionName: "vtt")
            ]
        )
    }
}
