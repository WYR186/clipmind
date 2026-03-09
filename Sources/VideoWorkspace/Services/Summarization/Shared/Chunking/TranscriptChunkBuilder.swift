import Foundation

struct TranscriptChunkBuilder {
    private let sizeBased: ChunkingStrategy
    private let segmentAware: ChunkingStrategy

    init(
        sizeBased: ChunkingStrategy = SizeBasedChunkingStrategy(),
        segmentAware: ChunkingStrategy = SegmentAwareChunkingStrategy()
    ) {
        self.sizeBased = sizeBased
        self.segmentAware = segmentAware
    }

    func buildChunks(
        transcript: TranscriptItem,
        strategy: SummaryChunkingStrategy,
        maxCharactersPerChunk: Int = 6_000
    ) -> [TranscriptChunk] {
        switch strategy {
        case .sizeBased:
            return sizeBased.chunk(transcript: transcript, maxCharactersPerChunk: maxCharactersPerChunk)
        case .segmentAware:
            return segmentAware.chunk(transcript: transcript, maxCharactersPerChunk: maxCharactersPerChunk)
        }
    }
}
