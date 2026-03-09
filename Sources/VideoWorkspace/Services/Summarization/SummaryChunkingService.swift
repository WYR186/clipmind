import Foundation

struct SummaryChunkingService {
    private let chunkBuilder: TranscriptChunkBuilder

    init(chunkBuilder: TranscriptChunkBuilder = TranscriptChunkBuilder()) {
        self.chunkBuilder = chunkBuilder
    }

    func makeChunks(for request: SummarizationRequest) throws -> [TranscriptChunk] {
        let transcript = request.transcript
        guard !transcript.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummarizationError.transcriptMissing
        }

        let chunks = chunkBuilder.buildChunks(
            transcript: transcript,
            strategy: request.summaryRequest.chunkingStrategy
        )

        if chunks.isEmpty {
            throw SummarizationError.transcriptMissing
        }

        return chunks
    }
}
