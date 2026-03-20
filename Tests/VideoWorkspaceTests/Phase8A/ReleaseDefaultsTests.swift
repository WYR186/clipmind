import XCTest
@testable import VideoWorkspace

final class ReleaseDefaultsTests: XCTestCase {
    func testDistributionFriendlyDefaults() {
        let settings = AppSettings()
        XCTAssertEqual(settings.defaults.videoQuality, "720p")
        XCTAssertEqual(settings.defaults.summaryLength, .medium)
        XCTAssertEqual(settings.defaults.summaryMode, .abstractSummary)
        XCTAssertTrue(settings.simpleModeEnabled)
        XCTAssertTrue(settings.defaults.transcriptionPreprocessingEnabled)
    }

    func testFailurePresentationConsistency() {
        let toolError = ErrorPresentationMapper.map(DownloadError.ytDLPNotFound, context: "Download")
        let outputError = ErrorPresentationMapper.map(
            DownloadError.outputDirectoryUnavailable(path: "/tmp/locked"),
            context: "Download"
        )
        let providerError = ErrorPresentationMapper.map(
            SummarizationError.localProviderNotRunning(provider: .ollama),
            context: "Summarization"
        )

        XCTAssertFalse(toolError.suggestions.isEmpty)
        XCTAssertTrue(toolError.suggestions.contains(.installExternalTools))
        XCTAssertTrue(outputError.suggestions.contains(.checkPermissions))
        XCTAssertTrue(providerError.suggestions.contains(.startLocalService))
    }

    func testReleaseReadinessDocsExist() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Resources/Docs/RELEASE_CHECKLIST.md"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Resources/Docs/QA_SMOKE_MATRIX.md"))
    }
}

