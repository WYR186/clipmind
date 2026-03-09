import XCTest
@testable import VideoWorkspace

final class FilenameStrategyTests: XCTestCase {
    func testSanitizeRemovesIllegalCharacters() {
        let strategy = DownloadFilenameStrategy()
        let value = strategy.sanitize("A/B:C*D?E\"F<G>H|I")
        XCTAssertFalse(value.contains("/"))
        XCTAssertFalse(value.contains(":"))
        XCTAssertFalse(value.contains("*"))
        XCTAssertFalse(value.contains("?"))
    }

    func testDefaultSubtitleName() {
        let strategy = DownloadFilenameStrategy()
        let request = MediaDownloadRequest(
            source: MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"),
            kind: .subtitle,
            metadataTitle: "My Course",
            selectedSubtitleTrack: SubtitleTrack(languageCode: "en", languageName: "English", sourceType: .native)
        )

        let base = strategy.makeBaseFileName(request: request, metadata: nil)
        XCTAssertTrue(base.contains("My Course"))
        XCTAssertTrue(base.contains("en"))
    }
}
