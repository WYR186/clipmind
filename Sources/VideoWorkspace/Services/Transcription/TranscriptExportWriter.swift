import Foundation

struct TranscriptExportWriter: TranscriptExporting {
    private let formatter: TranscriptSegmentFormatter

    init(formatter: TranscriptSegmentFormatter = TranscriptSegmentFormatter()) {
        self.formatter = formatter
    }

    func write(
        request: TranscriptionRequest,
        transcriptText: String,
        segments: [TranscriptSegment]
    ) throws -> [TranscriptArtifact] {
        let directoryURL = try resolveOutputDirectory(from: request.outputDirectory)
        let sourceName = URL(fileURLWithPath: request.sourcePath).deletingPathExtension().lastPathComponent
        let baseName = sanitizeFileName("\(sourceName)-transcript")

        let normalizedSegments = segments.isEmpty
            ? [TranscriptSegment(index: 0, startSeconds: 0, endSeconds: 3, text: transcriptText)]
            : segments

        var artifacts: [TranscriptArtifact] = []

        for outputKind in request.outputKinds {
            let fileURL = try resolveOutputFileURL(
                directoryURL: directoryURL,
                baseName: baseName,
                outputKind: outputKind,
                overwritePolicy: request.overwritePolicy
            )

            if request.overwritePolicy == .skip, FileManager.default.fileExists(atPath: fileURL.path) {
                artifacts.append(TranscriptArtifact(kind: outputKind, path: fileURL.path))
                continue
            }

            let content: String
            switch outputKind {
            case .txt:
                content = transcriptText
            case .srt:
                content = formatter.srt(from: normalizedSegments)
            case .vtt:
                content = formatter.vtt(from: normalizedSegments)
            }

            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                throw TranscriptionError.transcriptExportFailed(details: "Failed writing \(fileURL.path): \(error.localizedDescription)")
            }

            artifacts.append(TranscriptArtifact(kind: outputKind, path: fileURL.path))
        }

        return artifacts
    }

    private func resolveOutputDirectory(from path: String?) throws -> URL {
        let rawDirectory = (path?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? path!
            : "~/Downloads/VideoWorkspace/transcripts"
        let expanded = NSString(string: rawDirectory).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw TranscriptionError.transcriptExportFailed(details: "Output path is not a directory: \(url.path)")
            }
            return url
        }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch {
            throw TranscriptionError.transcriptExportFailed(details: "Cannot create output directory \(url.path)")
        }
    }

    private func resolveOutputFileURL(
        directoryURL: URL,
        baseName: String,
        outputKind: TranscriptOutputKind,
        overwritePolicy: FileOverwritePolicy
    ) throws -> URL {
        let ext = outputKind.rawValue

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
                    throw TranscriptionError.transcriptExportFailed(details: "Failed to resolve unique output file name")
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
        return clipped.isEmpty ? "transcript" : clipped
    }
}
