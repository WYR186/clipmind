import XCTest
@testable import VideoWorkspace

final class GeminiRequestBuilderTests: XCTestCase {
    func testBuildRequestUsesGenerateContentEndpoint() throws {
        let builder = GeminiRequestBuilder()
        let request = try builder.buildRequest(
            modelID: "gemini-2.0-flash",
            prompt: "Summarize",
            transcriptText: "transcript",
            apiKey: "g-key",
            structured: true
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.absoluteString.contains("generateContent") == true)
        XCTAssertTrue(request.url?.absoluteString.contains("key=g-key") == true)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("responseMimeType"))
    }
}
