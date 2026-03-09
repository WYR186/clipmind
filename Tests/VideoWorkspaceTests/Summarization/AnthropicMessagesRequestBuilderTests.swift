import XCTest
@testable import VideoWorkspace

final class AnthropicMessagesRequestBuilderTests: XCTestCase {
    func testBuildRequestSetsHeadersAndBody() throws {
        let builder = AnthropicMessagesRequestBuilder(endpoint: URL(string: "https://example.com/v1/messages")!)
        let request = try builder.buildRequest(
            modelID: "claude-3-7-sonnet",
            prompt: "Summarize in bullets",
            transcriptText: "content",
            apiKey: "key-1"
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "key-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("claude-3-7-sonnet"))
        XCTAssertTrue(body.contains("Summarize in bullets"))
    }
}
