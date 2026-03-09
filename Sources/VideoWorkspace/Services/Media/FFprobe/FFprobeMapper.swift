import Foundation

struct FFprobeMapper {
    func map(source: MediaSource, payload: FFprobeJSONModels.Root) throws -> MediaMetadata {
        guard source.type == .localFile else {
            throw ExternalToolError.unsupportedSourceType(source.type)
        }

        let videoOptions = mapVideoStreams(payload.streams)
        let audioOptions = mapAudioStreams(payload.streams)
        let subtitleTracks = mapSubtitleStreams(payload.streams)

        let durationSeconds = intFromString(payload.format?.duration) ?? 0
        let bitrate = intFromString(payload.format?.bitRate).map { $0 / 1000 }
        let fileSize = int64FromString(payload.format?.size)

        return MediaMetadata(
            source: source,
            title: URL(fileURLWithPath: source.value).lastPathComponent,
            durationSeconds: durationSeconds,
            thumbnailURL: nil,
            platform: "Local File",
            webpageURL: nil,
            container: payload.format?.formatName,
            bitrateKbps: bitrate,
            fileSizeBytes: fileSize,
            videoOptions: videoOptions,
            audioOptions: audioOptions,
            subtitleTracks: subtitleTracks
        )
    }

    private func mapVideoStreams(_ streams: [FFprobeJSONModels.StreamInfo]) -> [VideoFormatOption] {
        streams
            .filter { $0.codecType == "video" }
            .map { stream in
                let resolution = resolutionText(width: stream.width, height: stream.height)
                let fps = parseFrameRate(stream.avgFrameRate) ?? parseFrameRate(stream.rFrameRate)
                let quality = resolution ?? stream.codecName ?? "video"
                let fpsText = fps.map { String(format: "%.1f", $0) + "fps" }
                let display = [quality, stream.codecName, fpsText].compactMap { $0 }.joined(separator: " | ")

                return VideoFormatOption(
                    formatID: stream.index.map(String.init),
                    qualityLabel: quality,
                    displayLabel: display.isEmpty ? quality : display,
                    container: "stream",
                    extensionName: nil,
                    videoCodec: stream.codecName,
                    audioCodec: nil,
                    resolution: resolution,
                    width: stream.width,
                    height: stream.height,
                    fps: fps,
                    bitrateKbps: intFromString(stream.bitRate).map { $0 / 1000 },
                    fileSizeBytes: nil,
                    hasHDR: false,
                    isVideoOnly: true,
                    isAudioOnly: false
                )
            }
    }

    private func mapAudioStreams(_ streams: [FFprobeJSONModels.StreamInfo]) -> [AudioFormatOption] {
        streams
            .filter { $0.codecType == "audio" }
            .map { stream in
                let codec = stream.codecName ?? "unknown"
                let bitrateKbps = intFromString(stream.bitRate).map { $0 / 1000 } ?? 0
                let label = [codec, bitrateKbps > 0 ? "\(bitrateKbps)kbps" : nil].compactMap { $0 }.joined(separator: " | ")

                return AudioFormatOption(
                    formatID: stream.index.map(String.init),
                    extensionName: nil,
                    codec: codec,
                    bitrateKbps: bitrateKbps,
                    sampleRateHz: intFromString(stream.sampleRate),
                    channels: stream.channels,
                    fileSizeBytes: nil,
                    displayLabel: label.isEmpty ? codec : label
                )
            }
    }

    private func mapSubtitleStreams(_ streams: [FFprobeJSONModels.StreamInfo]) -> [SubtitleTrack] {
        streams
            .filter { $0.codecType == "subtitle" }
            .map { stream in
                let languageCode = stream.tags?["language"] ?? "und"
                let name = Locale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
                let codec = stream.codecName ?? "subtitle"
                return SubtitleTrack(
                    languageCode: languageCode,
                    languageName: name,
                    sourceType: .native,
                    extensionName: nil,
                    remoteURL: nil,
                    displayLabel: "\(name) (\(codec))"
                )
            }
    }

    private func resolutionText(width: Int?, height: Int?) -> String? {
        guard let width, let height else { return nil }
        return "\(width)x\(height)"
    }

    private func parseFrameRate(_ value: String?) -> Double? {
        guard let value, !value.isEmpty else { return nil }
        let components = value.split(separator: "/")
        if components.count == 2,
           let numerator = Double(components[0]),
           let denominator = Double(components[1]),
           denominator != 0 {
            return numerator / denominator
        }
        return Double(value)
    }

    private func intFromString(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(Double(value) ?? 0)
    }

    private func int64FromString(_ value: String?) -> Int64? {
        guard let value else { return nil }
        return Int64(Double(value) ?? 0)
    }
}
