import Foundation

// MARK: - Audio format

enum AudioOutputFormat: String, CaseIterable, Sendable {
    case mp3
    case m4a
    case aac
    case wav
    case flac
    case opus

    var codec: String {
        switch self {
        case .mp3: return "libmp3lame"
        case .m4a, .aac: return "aac"
        case .wav: return "pcm_s16le"
        case .flac: return "flac"
        case .opus: return "libopus"
        }
    }

    var supportsKbpsControl: Bool {
        switch self {
        case .wav, .flac: return false
        default: return true
        }
    }
}

// MARK: - Video format

enum VideoOutputFormat: String, CaseIterable, Sendable {
    case mp4
    case mkv
    case mov
    case webm

    var videoCodec: String {
        switch self {
        case .mp4, .mov: return "libx264"
        case .mkv: return "libx265"
        case .webm: return "libvpx-vp9"
        }
    }

    var audioCodec: String {
        switch self {
        case .mp4, .mov, .mkv: return "aac"
        case .webm: return "libopus"
        }
    }
}

// MARK: - Builder

struct FFmpegCommandBuilder {

    // MARK: Remux (stream copy, no re-encoding)

    func buildRemuxArguments(inputPath: String, outputPath: String) -> [String] {
        [
            "-y",
            "-i", inputPath,
            "-c", "copy",
            outputPath
        ]
    }

    // MARK: Audio extraction

    func buildAudioExtractionArguments(
        inputPath: String,
        outputPath: String,
        format: AudioOutputFormat = .mp3,
        quality: ConversionQuality = .medium,
        sampleRate: Int? = nil,
        channels: Int? = nil
    ) -> [String] {
        var args: [String] = ["-y", "-i", inputPath, "-vn"]

        args += ["-c:a", format.codec]

        if format.supportsKbpsControl && quality != .lossless {
            args += ["-b:a", "\(quality.audioKbps)k"]
        }

        if let sampleRate {
            args += ["-ar", "\(sampleRate)"]
        }

        if let channels {
            args += ["-ac", "\(channels)"]
        }

        args.append(outputPath)
        return args
    }

    // MARK: Video conversion

    func buildVideoConversionArguments(
        inputPath: String,
        outputPath: String,
        format: VideoOutputFormat = .mp4,
        quality: ConversionQuality = .medium,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil,
        frameRate: Double? = nil
    ) -> [String] {
        var args: [String] = ["-y", "-i", inputPath]

        args += ["-c:v", format.videoCodec]
        args += ["-c:a", format.audioCodec]

        if quality == .lossless {
            args += ["-crf", "0"]
        } else {
            args += ["-crf", "\(quality.videoCRF)"]
        }

        // Scale filter for resolution constraints
        if let w = maxWidth, let h = maxHeight {
            args += ["-vf", "scale=w=\(w):h=\(h):force_original_aspect_ratio=decrease,pad=\(w):\(h):(ow-iw)/2:(oh-ih)/2"]
        } else if let w = maxWidth {
            args += ["-vf", "scale=\(w):-2"]
        } else if let h = maxHeight {
            args += ["-vf", "scale=-2:\(h)"]
        }

        if let fps = frameRate {
            args += ["-r", String(format: "%.3g", fps)]
        }

        args += ["-movflags", "+faststart"]
        args.append(outputPath)
        return args
    }

    // MARK: Trim / clip

    func buildTrimArguments(
        inputPath: String,
        outputPath: String,
        startSeconds: Double,
        durationSeconds: Double? = nil,
        endSeconds: Double? = nil
    ) -> [String] {
        var args: [String] = [
            "-y",
            "-ss", String(format: "%.3f", startSeconds),
            "-i", inputPath
        ]

        if let duration = durationSeconds {
            args += ["-t", String(format: "%.3f", duration)]
        } else if let end = endSeconds {
            let duration = max(0, end - startSeconds)
            args += ["-t", String(format: "%.3f", duration)]
        }

        args += ["-c", "copy", outputPath]
        return args
    }

    // MARK: Thumbnail extraction

    func buildThumbnailArguments(
        inputPath: String,
        outputPath: String,
        atSeconds: Double = 0,
        width: Int = 640,
        height: Int = 360
    ) -> [String] {
        [
            "-y",
            "-ss", String(format: "%.3f", atSeconds),
            "-i", inputPath,
            "-frames:v", "1",
            "-vf", "scale=\(width):\(height):force_original_aspect_ratio=decrease",
            "-update", "1",
            outputPath
        ]
    }

    // MARK: Subtitle burn-in

    func buildSubtitleBurnArguments(
        inputPath: String,
        subtitlePath: String,
        outputPath: String,
        quality: ConversionQuality = .medium
    ) -> [String] {
        [
            "-y",
            "-i", inputPath,
            "-vf", "subtitles=\(subtitlePath.replacingOccurrences(of: ":", with: "\\:"))",
            "-c:v", "libx264",
            "-crf", "\(quality.videoCRF)",
            "-c:a", "copy",
            outputPath
        ]
    }

    // MARK: Probe arguments (get media info as JSON)

    func buildProbeArguments(inputPath: String) -> [String] {
        [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            inputPath
        ]
    }
}
