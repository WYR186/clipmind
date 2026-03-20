import XCTest
@testable import VideoWorkspace

final class ErrorPresentationMapperTests: XCTestCase {
    func testMapsDownloadToolMissingError() {
        let mapped = ErrorPresentationMapper.map(DownloadError.ytDLPNotFound, context: "Download")

        XCTAssertEqual(mapped.code, "DOWNLOAD_YTDLP_NOT_FOUND")
        XCTAssertEqual(mapped.service, "Download")
        XCTAssertTrue(mapped.suggestions.contains(.installExternalTools))
    }

    func testMapsSummarizationAPIKeyError() {
        let mapped = ErrorPresentationMapper.map(
            SummarizationError.apiKeyMissing(provider: .openAI),
            context: "Summarization"
        )

        XCTAssertEqual(mapped.code, "SUMMARY_API_KEY_MISSING")
        XCTAssertTrue(mapped.suggestions.contains(.configureAPIKey))
    }

    func testMapsNetworkError() {
        let mapped = ErrorPresentationMapper.map(URLError(.notConnectedToInternet), context: "Network")

        XCTAssertEqual(mapped.title, "Network Error")
        XCTAssertTrue(mapped.suggestions.contains(.verifyNetwork))
    }
}
