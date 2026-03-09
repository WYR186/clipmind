import XCTest
@testable import VideoWorkspace

final class LMStudioRequestBuilderTests: XCTestCase {
    func testBuildRequestContainsMessages() throws {
        let builder = LMStudioRequestBuilder(endpoint: URL(string: "http://localhost:1234/v1/chat/completions")!)
        let request = try builder.buildRequest(
            modelID: "local-model",
            prompt: "Use markdown",
            transcriptText: "sample transcript",
            structured: true
        )

        XCTAssertEqual(request.httpMethod, "POST")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("local-model"))
        XCTAssertTrue(body.contains("sample transcript"))
        XCTAssertTrue(body.contains("response_format"))
    }
}
