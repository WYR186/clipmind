import Foundation

protocol TranslationExportServiceProtocol: Sendable {
    func write(
        request: TranslationRequest,
        translatedText: String,
        bilingualText: String?,
        translatedSegments: [TranslationSegment]
    ) throws -> [TranslationArtifact]
}

struct TranslationExportService: TranslationExportServiceProtocol {
    private let formatter: TranscriptSegmentFormatter
    private let mapper: SubtitleTranslationMapper

    init(
        formatter: TranscriptSegmentFormatter = TranscriptSegmentFormatter(),
        mapper: SubtitleTranslationMapper = SubtitleTranslationMapper()
    ) {
        self.formatter = formatter
        self.mapper = mapper
    }

    func write(
        request: TranslationRequest,
        translatedText: String,
        bilingualText: String?,
        translatedSegments: [TranslationSegment]
    ) throws -> [TranslationArtifact] {
        let directoryURL = try resolveOutputDirectory(from: request.outputDirectory)
        let baseName = sanitizeFileName("translation-\(request.taskID.uuidString.prefix(8))")
        let outputFormats = request.outputFormats.isEmpty ? [TranslationOutputFormat.txt] : request.outputFormats

        var artifacts: [TranslationArtifact] = []
        for format in outputFormats {
            let fileURL = try resolveOutputFileURL(
                directoryURL: directoryURL,
                baseName: baseName,
                outputFormat: format,
                overwritePolicy: request.overwritePolicy
            )

            if request.overwritePolicy == .skip, FileManager.default.fileExists(atPath: fileURL.path) {
                artifacts.append(TranslationArtifact(format: format, path: fileURL.path))
                continue
            }

            let payload = try makePayload(
                format: format,
                translatedText: translatedText,
                bilingualText: bilingualText,
                translatedSegments: translatedSegments
            )

            do {
                try payload.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                throw TranslationError.exportFailed(details: "Failed writing \(fileURL.path): \(error.localizedDescription)")
            }

            artifacts.append(TranslationArtifact(format: format, path: fileURL.path))
        }

        return artifacts
    }

    private func makePayload(
        format: TranslationOutputFormat,
        translatedText: String,
        bilingualText: String?,
        translatedSegments: [TranslationSegment]
    ) throws -> String {
        switch format {
        case .txt:
            return bilingualText ?? translatedText
        case .markdown:
            if let bilingualText {
                return "# Bilingual Translation\n\n\(bilingualText)\n"
            }
            return "# Translation\n\n\(translatedText)\n"
        case .srt:
            guard !translatedSegments.isEmpty else {
                throw TranslationError.subtitleStructureUnavailable(format: .srt)
            }
            return formatter.srt(from: mapper.subtitleSegments(from: translatedSegments))
        case .vtt:
            guard !translatedSegments.isEmpty else {
                throw TranslationError.subtitleStructureUnavailable(format: .vtt)
            }
            return formatter.vtt(from: mapper.subtitleSegments(from: translatedSegments))
        }
    }

    private func resolveOutputDirectory(from path: String?) throws -> URL {
        let rawDirectory = (path?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? path!
            : "~/Downloads/VideoWorkspace/translations"
        let expanded = NSString(string: rawDirectory).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw TranslationError.exportFailed(details: "Output path is not a directory: \(url.path)")
            }
            return url
        }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch {
            throw TranslationError.exportFailed(details: "Cannot create output directory \(url.path)")
        }
    }

    private func resolveOutputFileURL(
        directoryURL: URL,
        baseName: String,
        outputFormat: TranslationOutputFormat,
        overwritePolicy: FileOverwritePolicy
    ) throws -> URL {
        let ext: String
        switch outputFormat {
        case .txt:
            ext = "txt"
        case .markdown:
            ext = "md"
        case .srt:
            ext = "srt"
        case .vtt:
            ext = "vtt"
        }

        switch overwritePolicy {
        case .replace, .skip:
            return directoryURL.appendingPathComponent("\(baseName).\(ext)")
        case .renameIfNeeded:
            var candidate = directoryURL.appendingPathComponent("\(baseName).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }

            var counter = 2
            while true {
                candidate = directoryURL.appendingPathComponent("\(baseName)-\(counter).\(ext)")
                if !FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
                counter += 1
                if counter > 10_000 {
                    throw TranslationError.exportFailed(details: "Failed to resolve unique translation output file name")
                }
            }
        }
    }

    private func sanitizeFileName(_ input: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleanedScalars = input.unicodeScalars.map { scalar -> Character in
            invalid.contains(scalar) ? "-" : Character(scalar)
        }
        let cleaned = String(cleanedScalars)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let clipped = String(collapsed.prefix(120))
        return clipped.isEmpty ? "translation" : clipped
    }
}
