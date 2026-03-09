import Foundation

struct OpenAITranscriptionMapper {
    func mapSegments(from response: OpenAITranscriptionResponse) -> [TranscriptSegment] {
        guard let segments = response.segments, !segments.isEmpty else {
            return []
        }

        return segments.enumerated().map { index, segment in
            TranscriptSegment(
                index: index,
                startSeconds: segment.start,
                endSeconds: segment.end,
                text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}
