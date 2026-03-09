import XCTest
@testable import VideoWorkspace

final class OpenAITranscriptionMapperTests: XCTestCase {
    func testMapSegments() {
        let response = OpenAITranscriptionResponse(
            text: "hello world",
            language: "en",
            duration: 4.2,
            segments: [
                OpenAITranscriptionSegment(id: 0, start: 0.0, end: 1.5, text: "hello"),
                OpenAITranscriptionSegment(id: 1, start: 1.5, end: 4.2, text: "world")
            ]
        )

        let mapper = OpenAITranscriptionMapper()
        let segments = mapper.mapSegments(from: response)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].text, "hello")
        XCTAssertEqual(segments[1].endSeconds, 4.2, accuracy: 0.001)
    }
}
