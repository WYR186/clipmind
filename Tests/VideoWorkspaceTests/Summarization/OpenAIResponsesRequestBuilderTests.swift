import XCTest
@testable import VideoWorkspace

final class OpenAIResponsesRequestBuilderTests: XCTestCase {
    func testBuildRequestIncludesModelAndInput() throws {
        let builder = OpenAIResponsesRequestBuilder(endpoint: URL(string: "https://example.com/v1/responses")!)
        let request = try builder.buildRequest(
            modelID: "gpt-4.1-mini",
            prompt: "Summarize",
            transcriptText: "hello world",
            apiKey: "k",
            structured: true
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer k")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("gpt-4.1-mini"))
        XCTAssertTrue(body.contains("hello world"))
        XCTAssertTrue(body.contains("json_schema"))
    }
}
