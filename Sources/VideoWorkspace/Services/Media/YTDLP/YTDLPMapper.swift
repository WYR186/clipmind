import Foundation

struct YTDLPMapper {
    func map(source: MediaSource, payload: YTDLPJSONModels.Root) throws -> MediaMetadata {
        guard source.type == .url else {
            throw ExternalToolError.unsupportedSourceType(source.type)
        }

        let videoOptions = mapVideoFormats(payload.formats)
        let audioOptions = mapAudioFormats(payload.formats)
        let subtitleTracks = mapSubtitles(nativeTracks: payload.subtitles, autoTracks: payload.automaticCaptions)

        return MediaMetadata(
            source: source,
            title: payload.title ?? source.value,
            durationSeconds: Int(payload.duration ?? 0),
            thumbnailURL: payload.thumbnail,
            platform: payload.extractor ?? payload.extractorKey,
            webpageURL: payload.webpageURL,
            container: nil,
            bitrateKbps: nil,
            fileSizeBytes: nil,
            videoOptions: videoOptions,
            audioOptions: audioOptions,
            subtitleTracks: subtitleTracks
        )
    }

    private func mapVideoFormats(_ formats: [YTDLPJSONModels.Format]) -> [VideoFormatOption] {
        formats
            .filter { format in
                guard let vcodec = format.vcodec else { return false }
                return vcodec != "none"
            }
            .map { format in
                let resolution = resolutionText(width: format.width, height: format.height)
                let quality = format.formatNote ?? resolution ?? format.formatDescription ?? "video"
                let fpsText = format.fps.map { String(format: "%.0f", $0) + "fps" } ?? nil
                let display = [quality, fpsText, format.vcodec].compactMap { $0 }.joined(separator: " | ")

                return VideoFormatOption(
                    formatID: format.formatID,
                    qualityLabel: quality,
                    displayLabel: display.isEmpty ? quality : display,
                    container: format.container ?? format.ext ?? "unknown",
                    extensionName: format.ext,
                    videoCodec: format.vcodec,
                    audioCodec: format.acodec,
                    resolution: resolution,
                    width: format.width,
                    height: format.height,
                    fps: format.fps,
                    bitrateKbps: intFromDouble(format.tbr),
                    fileSizeBytes: format.fileSize,
                    hasHDR: false,
                    isVideoOnly: format.acodec == "none",
                    isAudioOnly: false
                )
            }
    }

    private func mapAudioFormats(_ formats: [YTDLPJSONModels.Format]) -> [AudioFormatOption] {
        let audioOnly = formats.filter { $0.acodec != nil && $0.acodec != "none" && $0.vcodec == "none" }
        let source = audioOnly.isEmpty ? formats.filter { $0.acodec != nil && $0.acodec != "none" } : audioOnly

        return source.map { format in
            let bitrate = intFromDouble(format.abr) ?? intFromDouble(format.tbr) ?? 0
            let codec = format.acodec ?? "unknown"
            let label = [codec, bitrate > 0 ? "\(bitrate)kbps" : nil, format.ext].compactMap { $0 }.joined(separator: " | ")

            return AudioFormatOption(
                formatID: format.formatID,
                extensionName: format.ext,
                codec: codec,
                bitrateKbps: bitrate,
                sampleRateHz: format.asr,
                channels: format.audioChannels,
                fileSizeBytes: format.fileSize,
                displayLabel: label.isEmpty ? codec : label
            )
        }
    }

    private func mapSubtitles(
        nativeTracks: [String: [YTDLPJSONModels.SubtitleItem]],
        autoTracks: [String: [YTDLPJSONModels.SubtitleItem]]
    ) -> [SubtitleTrack] {
        var tracks: [SubtitleTrack] = []

        for (lang, entries) in nativeTracks {
            tracks.append(contentsOf: makeSubtitleTracks(languageCode: lang, entries: entries, sourceType: .native))
        }
        for (lang, entries) in autoTracks {
            tracks.append(contentsOf: makeSubtitleTracks(languageCode: lang, entries: entries, sourceType: .auto))
        }

        var seen = Set<String>()
        return tracks.filter { track in
            let key = "\(track.languageCode)|\(track.sourceType.rawValue)|\(track.extensionName ?? "")|\(track.remoteURL ?? "")"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    private func makeSubtitleTracks(
        languageCode: String,
        entries: [YTDLPJSONModels.SubtitleItem],
        sourceType: SubtitleSourceType
    ) -> [SubtitleTrack] {
        if entries.isEmpty {
            return [SubtitleTrack(languageCode: languageCode, languageName: languageName(for: languageCode), sourceType: sourceType)]
        }

        return entries.map { entry in
            SubtitleTrack(
                languageCode: languageCode,
                languageName: languageName(for: languageCode),
                sourceType: sourceType,
                extensionName: entry.ext,
                remoteURL: entry.url,
                displayLabel: "\(languageName(for: languageCode)) (\(sourceType.rawValue), \(entry.ext ?? "unknown"))"
            )
        }
    }

    private func languageName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    private func resolutionText(width: Int?, height: Int?) -> String? {
        guard let width, let height else {
            return nil
        }
        return "\(width)x\(height)"
    }

    private func intFromDouble(_ value: Double?) -> Int? {
        guard let value else { return nil }
        return Int(value.rounded())
    }
}
