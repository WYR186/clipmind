import XCTest
@testable import VideoWorkspace

final class ExpandedSourceMapperTests: XCTestCase {
    func testMapToBatchCreationRequestUsesSelectedValidItemsAndPlaylistMetadata() throws {
        let mapper = ExpandedSourceMapper()
        let template = BatchOperationTemplate.fromDefaults(
            operationType: .summarize,
            defaults: DefaultPreferences()
        )

        let result = SourceExpansionResult(
            sourceKind: .playlistURL,
            sourceURL: "https://youtube.com/playlist?list=PL123",
            playlistMetadata: PlaylistMetadata(
                title: "Playlist A",
                sourceURL: "https://youtube.com/playlist?list=PL123",
                entryCount: 3,
                extractor: "youtube",
                thumbnailURL: nil
            ),
            status: .partial,
            expandedItems: [
                ExpandedSourceItem(displayTitle: "A", sourceURL: "https://youtube.com/watch?v=1", originalIndex: 0, isSelected: true, isValid: true),
                ExpandedSourceItem(displayTitle: "A duplicate", sourceURL: "https://youtube.com/watch?v=1", originalIndex: 1, isSelected: true, isValid: true),
                ExpandedSourceItem(displayTitle: "B", sourceURL: "https://youtube.com/watch?v=2", originalIndex: 2, isSelected: false, isValid: true)
            ],
            skippedItems: []
        )

        let request = try mapper.mapToBatchCreationRequest(
            expansionResult: result,
            operationTemplate: template,
            preferredTitle: nil
        )

        XCTAssertEqual(request.sourceType, .urlBatch)
        XCTAssertEqual(request.sources.count, 1)
        XCTAssertTrue((request.title ?? "").contains("Playlist A"))
        XCTAssertEqual(request.sourceDescriptor, "playlist:Playlist A")
        XCTAssertNotNil(request.sourceMetadataJSON)
    }

    func testMapToBatchCreationRequestThrowsWhenNoSelectedItems() {
        let mapper = ExpandedSourceMapper()
        let template = BatchOperationTemplate.fromDefaults(
            operationType: .exportAudio,
            defaults: DefaultPreferences()
        )

        let result = SourceExpansionResult(
            sourceKind: .playlistURL,
            sourceURL: "https://youtube.com/playlist?list=PL123",
            playlistMetadata: nil,
            status: .empty,
            expandedItems: [
                ExpandedSourceItem(displayTitle: "A", sourceURL: "https://youtube.com/watch?v=1", originalIndex: 0, isSelected: false, isValid: true)
            ],
            skippedItems: []
        )

        XCTAssertThrowsError(
            try mapper.mapToBatchCreationRequest(
                expansionResult: result,
                operationTemplate: template,
                preferredTitle: nil
            )
        ) { error in
            guard case ExpandedSourceMapperError.noSelectedItems = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
