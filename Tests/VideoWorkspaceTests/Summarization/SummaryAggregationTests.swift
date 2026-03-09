import XCTest
@testable import VideoWorkspace

final class SummaryAggregationTests: XCTestCase {
    func testCombineChunkSummaries() throws {
        let service = SummaryAggregationService()
        let combined = try service.combineChunkSummaries(["A", "B"])

        XCTAssertTrue(combined.contains("Chunk 1"))
        XCTAssertTrue(combined.contains("Chunk 2"))
    }

    func testMergeStructuredPayloads() {
        let service = SummaryAggregationService()
        let merged = service.mergeStructuredPayloads([
            StructuredSummaryPayload(title: "t1", keyPoints: ["p1"], actionItems: ["a1"]),
            StructuredSummaryPayload(title: nil, keyPoints: ["p2"], actionItems: ["a2"])
        ])

        XCTAssertEqual(merged.title, "t1")
        XCTAssertTrue(merged.keyPoints.contains("p1"))
        XCTAssertTrue(merged.keyPoints.contains("p2"))
        XCTAssertTrue(merged.actionItems.contains("a1"))
        XCTAssertTrue(merged.actionItems.contains("a2"))
    }
}
