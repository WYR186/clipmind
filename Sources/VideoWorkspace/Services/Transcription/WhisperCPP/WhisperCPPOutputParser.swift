import Foundation

struct WhisperCPPParsedOutput: Sendable {
    let text: String
    let segments: [TranscriptSegment]
}

struct WhisperCPPOutputParser {
    func parse(outputBasePath: String) throws -> WhisperCPPParsedOutput {
        let textPath = outputBasePath + ".txt"
        guard let textData = FileManager.default.contents(atPath: textPath),
              let text = String(data: textData, encoding: .utf8) else {
            throw TranscriptionError.whisperOutputParseFailed(details: "whisper text output missing")
        }

        let srtPath = outputBasePath + ".srt"
        let vttPath = outputBasePath + ".vtt"

        var segments: [TranscriptSegment] = []
        if let srtData = FileManager.default.contents(atPath: srtPath),
           let srt = String(data: srtData, encoding: .utf8) {
            segments = parseSRT(srt)
        } else if let vttData = FileManager.default.contents(atPath: vttPath),
                  let vtt = String(data: vttData, encoding: .utf8) {
            segments = parseVTT(vtt)
        }

        return WhisperCPPParsedOutput(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: segments
        )
    }

    private func parseSRT(_ content: String) -> [TranscriptSegment] {
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var segments: [TranscriptSegment] = []

        for (index, block) in blocks.enumerated() {
            let lines = block
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            guard lines.count >= 2 else { continue }
            let timeLineIndex = lines.first?.contains("-->") == true ? 0 : 1
            guard lines.indices.contains(timeLineIndex) else { continue }

            let timeLine = lines[timeLineIndex]
            let textLines = Array(lines.dropFirst(timeLineIndex + 1))
            let text = textLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let parts = timeLine.components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = parseTimestamp(parts[0]),
                  let end = parseTimestamp(parts[1]) else {
                continue
            }

            segments.append(TranscriptSegment(index: index, startSeconds: start, endSeconds: end, text: text))
        }

        return segments
    }

    private func parseVTT(_ content: String) -> [TranscriptSegment] {
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var segments: [TranscriptSegment] = []
        var index = 0
        var pointer = 0

        while pointer < lines.count {
            let line = lines[pointer].trimmingCharacters(in: .whitespaces)
            if line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                if parts.count == 2,
                   let start = parseTimestamp(parts[0]),
                   let end = parseTimestamp(parts[1]) {
                    pointer += 1
                    var textLines: [String] = []
                    while pointer < lines.count {
                        let textLine = lines[pointer].trimmingCharacters(in: .whitespacesAndNewlines)
                        if textLine.isEmpty { break }
                        if textLine.contains("-->") { break }
                        textLines.append(textLine)
                        pointer += 1
                    }

                    let text = textLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        segments.append(TranscriptSegment(index: index, startSeconds: start, endSeconds: end, text: text))
                        index += 1
                    }
                }
            }
            pointer += 1
        }

        return segments
    }

    private func parseTimestamp(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let cleaned = trimmed.replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]) else {
            return nil
        }

        let secondPart = String(parts[2])
        guard let seconds = Double(secondPart) else {
            return nil
        }

        return hours * 3600 + minutes * 60 + seconds
    }
}
