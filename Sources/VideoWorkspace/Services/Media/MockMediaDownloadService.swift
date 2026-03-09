import Foundation

struct MockMediaDownloadService: MediaDownloadServiceProtocol {
    func download(
        request: MediaDownloadRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> MediaDownloadResult {
        progressHandler?(TaskProgressFactory.step(0.2, description: "Preparing download"))
        try await Task.sleep(nanoseconds: 220_000_000)
        progressHandler?(TaskProgressFactory.step(0.6, description: "Downloading"))
        try await Task.sleep(nanoseconds: 220_000_000)
        progressHandler?(TaskProgressFactory.step(1.0, description: "Completed"))

        let suffix: String
        switch request.kind {
        case .video:
            suffix = "video.mp4"
        case .audioOnly:
            suffix = "audio.m4a"
        case .subtitle:
            suffix = "subtitle.\((request.preferredSubtitleFormat ?? .vtt).rawValue)"
        }

        let outputPath = "/tmp/videoworkspace/\(UUID().uuidString)-\(suffix)"
        return MediaDownloadResult(
            kind: request.kind,
            outputPath: outputPath,
            outputFileName: URL(fileURLWithPath: outputPath).lastPathComponent,
            usedVideoFormatID: request.selectedVideoFormatID,
            usedAudioFormatID: request.selectedAudioFormatID,
            subtitleLanguage: request.selectedSubtitleTrack?.languageCode
        )
    }
}
