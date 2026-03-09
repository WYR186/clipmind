import Foundation

protocol ChunkingStrategy: Sendable {
    func chunk(transcript: TranscriptItem, maxCharactersPerChunk: Int) -> [TranscriptChunk]
}

struct SizeBasedChunkingStrategy: ChunkingStrategy {
    func chunk(transcript: TranscriptItem, maxCharactersPerChunk: Int) -> [TranscriptChunk] {
        let text = transcript.content
        guard !text.isEmpty else { return [] }

        var chunks: [TranscriptChunk] = []
        var cursor = text.startIndex
        var index = 0

        while cursor < text.endIndex {
            let end = text.index(cursor, offsetBy: maxCharactersPerChunk, limitedBy: text.endIndex) ?? text.endIndex
            let slice = text[cursor..<end]
            chunks.append(TranscriptChunk(index: index, text: String(slice).trimmingCharacters(in: .whitespacesAndNewlines)))
            cursor = end
            index += 1
        }

        return chunks.filter { !$0.text.isEmpty }
    }
}

struct SegmentAwareChunkingStrategy: ChunkingStrategy {
    func chunk(transcript: TranscriptItem, maxCharactersPerChunk: Int) -> [TranscriptChunk] {
        guard !transcript.segments.isEmpty else {
            return SizeBasedChunkingStrategy().chunk(transcript: transcript, maxCharactersPerChunk: maxCharactersPerChunk)
        }

        var chunks: [TranscriptChunk] = []
        var buffer: [TranscriptSegment] = []
        var bufferCharacters = 0
        var chunkIndex = 0

        for segment in transcript.segments {
            let segmentLength = segment.text.count + 1
            if !buffer.isEmpty, bufferCharacters + segmentLength > maxCharactersPerChunk {
                chunks.append(buildChunk(from: buffer, index: chunkIndex))
                buffer.removeAll(keepingCapacity: true)
                bufferCharacters = 0
                chunkIndex += 1
            }

            buffer.append(segment)
            bufferCharacters += segmentLength
        }

        if !buffer.isEmpty {
            chunks.append(buildChunk(from: buffer, index: chunkIndex))
        }

        return chunks
    }

    private func buildChunk(from segments: [TranscriptSegment], index: Int) -> TranscriptChunk {
        TranscriptChunk(
            index: index,
            text: segments.map { $0.text }.joined(separator: "\n"),
            startSeconds: segments.first?.startSeconds,
            endSeconds: segments.last?.endSeconds
        )
    }
}
