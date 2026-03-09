import Foundation

struct YTDLPDownloadCommandBuilder {
    func buildArguments(request: MediaDownloadRequest, outputTemplatePath: String) throws -> [String] {
        guard request.source.type == .url else {
            throw DownloadError.invalidSelection(reason: "Download source must be an online URL.")
        }

        var args: [String] = ["--no-warnings", "--newline", "--no-playlist"]

        if request.resumeEnabled {
            args.append("--continue")
        } else {
            args.append("--no-continue")
        }

        switch request.overwritePolicy {
        case .replace:
            args.append("--force-overwrites")
        case .skip, .renameIfNeeded:
            args.append("--no-overwrites")
        }

        args += ["-o", outputTemplatePath]

        switch request.kind {
        case .subtitle:
            guard let subtitleTrack = request.selectedSubtitleTrack else {
                throw DownloadError.invalidSelection(reason: "Subtitle track is required.")
            }

            args += ["--skip-download"]
            if subtitleTrack.sourceType == .auto {
                args += ["--write-auto-subs"]
            } else {
                args += ["--write-subs"]
            }
            args += ["--sub-langs", subtitleTrack.languageCode]
            if let preferred = request.preferredSubtitleFormat {
                args += ["--convert-subs", preferred.rawValue]
            }

        case .audioOnly:
            let formatExpression = request.selectedAudioFormatID ?? "bestaudio"
            args += ["-f", formatExpression]

        case .video:
            if let videoID = request.selectedVideoFormatID, let audioID = request.selectedAudioFormatID {
                args += ["-f", "\(videoID)+\(audioID)/\(videoID)"]
            } else if let videoID = request.selectedVideoFormatID {
                args += ["-f", "\(videoID)+bestaudio/\(videoID)"]
            } else {
                args += ["-f", "bestvideo[height<=720]+bestaudio/best[height<=720]/best"]
            }
        }

        args += ["--", request.source.value]
        return args
    }
}
