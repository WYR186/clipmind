import Foundation

struct DownloadFilenameStrategy {
    func makeBaseFileName(request: MediaDownloadRequest, metadata: MediaMetadata?) -> String {
        if let preferred = request.preferredFileName?.trimmingCharacters(in: .whitespacesAndNewlines), !preferred.isEmpty {
            return sanitize(preferred)
        }

        let title = sanitize((request.metadataTitle ?? metadata?.title ?? request.source.value))
        switch request.kind {
        case .video:
            let quality = resolveQualityLabel(request: request, metadata: metadata)
            return sanitize("\(title)-\(quality)")
        case .audioOnly:
            return sanitize("\(title)-audio")
        case .subtitle:
            let language = request.selectedSubtitleTrack?.languageCode ?? "unknown"
            return sanitize("\(title)-\(language)-subtitle")
        }
    }

    private func resolveQualityLabel(request: MediaDownloadRequest, metadata: MediaMetadata?) -> String {
        guard let selectedVideoFormatID = request.selectedVideoFormatID,
              let option = metadata?.videoOptions.first(where: { $0.formatID == selectedVideoFormatID }) else {
            return "video"
        }
        return option.qualityLabel.replacingOccurrences(of: " ", with: "-")
    }

    func sanitize(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let cleaned = raw.unicodeScalars.map { invalid.contains($0) ? "-" : Character($0) }
        let collapsed = String(cleaned)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if collapsed.isEmpty {
            return "download"
        }

        let maxLength = 120
        if collapsed.count <= maxLength {
            return collapsed
        }
        return String(collapsed.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
