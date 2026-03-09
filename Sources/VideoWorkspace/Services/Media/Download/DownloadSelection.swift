import Foundation

struct DownloadSelection: Sendable {
    let kind: DownloadKind
    let videoFormatID: String?
    let audioFormatID: String?
    let subtitleTrack: SubtitleTrack?

    func validate(against metadata: MediaMetadata) throws {
        switch kind {
        case .video:
            if let videoFormatID,
               !metadata.videoOptions.contains(where: { $0.formatID == videoFormatID }) {
                throw DownloadError.invalidSelection(reason: "Selected video format is unavailable.")
            }
        case .audioOnly:
            if let audioFormatID,
               !metadata.audioOptions.contains(where: { $0.formatID == audioFormatID }) {
                throw DownloadError.invalidSelection(reason: "Selected audio format is unavailable.")
            }
        case .subtitle:
            guard let subtitleTrack else {
                throw DownloadError.invalidSelection(reason: "Please select a subtitle track.")
            }
            if !metadata.subtitleTracks.contains(where: { $0.id == subtitleTrack.id }) {
                throw DownloadError.invalidSelection(reason: "Selected subtitle track is unavailable.")
            }
        }
    }
}
