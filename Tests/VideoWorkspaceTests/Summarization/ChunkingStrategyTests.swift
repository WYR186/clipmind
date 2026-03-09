import XCTest
@testable import VideoWorkspace

final class ChunkingStrategyTests: XCTestCase {
    func testSizeBasedChunkingSplitsLongTranscript() {
        let transcript = TranscriptItem(
            taskID: UUID(),
            sourceType: .asr,
            languageCode: "en",
            format: .txt,
            content: String(repeating: "A", count: 15_000)
        )

        let builder = TranscriptChunkBuilder()
        let chunks = builder.buildChunks(transcript: transcript, strategy: .sizeBased, maxCharactersPerChunk: 6_000)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].index, 0)
        XCTAssertEqual(chunks[2].index, 2)
    }

    func testSegmentAwareChunkingPreservesTimeWindow() {
        let segments = [
            TranscriptSegment(index: 0, startSeconds: 0, endSeconds: 10, text: "Intro"),
            TranscriptSegment(index: 1, startSeconds: 10, endSeconds: 20, text: "Part A"),
            TranscriptSegment(index: 2, startSeconds: 20, endSeconds: 30, text: "Part B")
        ]

        let transcript = TranscriptItem(
            taskID: UUID(),
            sourceType: .asr,
            languageCode: "en",
            format: .txt,
            content: segments.map(\.text).joined(separator: "\n"),
            segments: segments
        )

        let builder = TranscriptChunkBuilder()
        let chunks = builder.buildChunks(transcript: transcript, strategy: .segmentAware, maxCharactersPerChunk: 12)

        XCTAssertGreaterThanOrEqual(chunks.count, 2)
        XCTAssertEqual(chunks.first?.startSeconds, 0)
        XCTAssertEqual(chunks.first?.endSeconds, 10)
    }
}
