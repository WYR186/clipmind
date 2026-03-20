import XCTest
@testable import VideoWorkspace

final class SourceExpansionServiceTests: XCTestCase {
    func testPlaylistURLRecognition() {
        let service = SourceExpansionService(
            playlistExpansionService: StubPlaylistExpansionService(),
            logger: ConsoleLogger()
        )

        XCTAssertTrue(service.isLikelyPlaylistURL("https://www.youtube.com/playlist?list=PL123"))
        XCTAssertTrue(service.isLikelyPlaylistURL("https://www.bilibili.com/medialist/play/ml123"))
        XCTAssertFalse(service.isLikelyPlaylistURL("https://www.youtube.com/watch?v=abc"))
    }

    func testExpandURLTextBlobFiltersInvalidAndDuplicates() async throws {
        let service = SourceExpansionService(
            playlistExpansionService: StubPlaylistExpansionService(),
            logger: ConsoleLogger()
        )

        let result = try await service.expand(
            request: SourceExpansionRequest(
                source: .urlTextBlob(
                    """
                    https://example.com/a
                    invalid-url
                    https://example.com/a
                    https://example.com/b
                    """
                ),
                sourceTypeHint: .multiURL,
                deduplicationPolicy: .normalizedURL,
                selectionDefault: .selectAllValid
            )
        )

        XCTAssertEqual(result.sourceKind, .multiURL)
        XCTAssertEqual(result.expandedItems.count, 2)
        XCTAssertEqual(result.skippedItems.count, 2)
        XCTAssertEqual(result.selectedCount, 2)
        XCTAssertEqual(Set(result.expandedItems.compactMap(\.sourceURL)).count, 2)
    }

    func testExpandSingleURLRespectsSelectionDefault() async throws {
        let service = SourceExpansionService(
            playlistExpansionService: StubPlaylistExpansionService(),
            logger: ConsoleLogger()
        )

        let result = try await service.expand(
            request: SourceExpansionRequest(
                source: .singleURL("https://example.com/video"),
                sourceTypeHint: .singleURL,
                selectionDefault: .selectNone
            )
        )

        XCTAssertEqual(result.sourceKind, .singleURL)
        XCTAssertEqual(result.expandedItems.count, 1)
        XCTAssertFalse(result.expandedItems[0].isSelected)
    }
}

private struct StubPlaylistExpansionService: PlaylistExpansionServiceProtocol {
    func expandPlaylist(
        url: String,
        deduplicationPolicy: SourceDeduplicationPolicy,
        selectionDefault: ExpandedSourceSelectionDefault
    ) async throws -> SourceExpansionResult {
        _ = deduplicationPolicy
        _ = selectionDefault
        return SourceExpansionResult(
            sourceKind: .playlistURL,
            sourceURL: url,
            playlistMetadata: PlaylistMetadata(
                title: "Stub Playlist",
                sourceURL: url,
                entryCount: 0,
                extractor: "stub",
                thumbnailURL: nil
            ),
            status: .empty,
            expandedItems: [],
            skippedItems: []
        )
    }
}
