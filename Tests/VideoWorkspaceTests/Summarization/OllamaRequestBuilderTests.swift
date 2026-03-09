import XCTest
@testable import VideoWorkspace

final class OllamaRequestBuilderTests: XCTestCase {
    func testBuildRequestContainsModelAndTranscript() throws {
        let builder = OllamaRequestBuilder(endpoint: URL(string: "http://localhost:11434/api/chat")!)
        let request = try builder.buildRequest(
            modelID: "qwen3:8b",
            prompt: "Key points",
            transcriptText: "hello",
            structured: false
        )

        XCTAssertEqual(request.httpMethod, "POST")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("qwen3:8b"))
        XCTAssertTrue(body.contains("hello"))
    }
}
