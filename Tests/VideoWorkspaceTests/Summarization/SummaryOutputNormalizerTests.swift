import XCTest
@testable import VideoWorkspace

final class SummaryOutputNormalizerTests: XCTestCase {
    func testNormalizeBulletText() throws {
        let normalizer = SummaryOutputNormalizer()
        let payload = try normalizer.normalize(
            text: "# Title\n- point one\n- point two",
            mode: .keyPoints
        )

        XCTAssertEqual(payload.title, "Title")
        XCTAssertEqual(payload.keyPoints.count, 2)
    }

    func testNormalizeJSONPayload() throws {
        let normalizer = SummaryOutputNormalizer()
        let json = """
        {"title":"Session","keyPoints":["A","B"],"sections":[]}
        """
        let payload = try normalizer.normalize(text: json, mode: .abstractSummary)
        XCTAssertEqual(payload.title, "Session")
        XCTAssertEqual(payload.keyPoints.count, 2)
    }
}
