import Foundation

struct TranscriptSegmentFormatter {
    func srt(from segments: [TranscriptSegment]) -> String {
        segments.enumerated().map { index, segment in
            """
            \(index + 1)
            \(srtTimestamp(segment.startSeconds)) --> \(srtTimestamp(segment.endSeconds))
            \(segment.text)
            """
        }.joined(separator: "\n\n") + "\n"
    }

    func vtt(from segments: [TranscriptSegment]) -> String {
        let body = segments.map { segment in
            """
            \(vttTimestamp(segment.startSeconds)) --> \(vttTimestamp(segment.endSeconds))
            \(segment.text)
            """
        }.joined(separator: "\n\n")

        return "WEBVTT\n\n\(body)\n"
    }

    private func srtTimestamp(_ seconds: Double) -> String {
        timestamp(seconds, separator: ",")
    }

    private func vttTimestamp(_ seconds: Double) -> String {
        timestamp(seconds, separator: ".")
    }

    private func timestamp(_ seconds: Double, separator: String) -> String {
        let totalMs = Int((seconds * 1000).rounded())
        let hours = totalMs / 3_600_000
        let minutes = (totalMs % 3_600_000) / 60_000
        let secs = (totalMs % 60_000) / 1_000
        let ms = totalMs % 1_000
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, secs, separator, ms)
    }
}
