import XCTest
@testable import VideoWorkspace

final class PlaylistToBatchFlowTests: XCTestCase {
    func testCreateBatchFromPlaylistExpansionPersistsSourceMetadata() async throws {
        let repository = InMemoryBatchJobRepository()
        let batchCreation = BatchCreationService(batchRepository: repository, logger: ConsoleLogger())
        let mapper = ExpandedSourceMapper()

        let template = BatchOperationTemplate.fromDefaults(
            operationType: .transcribe,
            defaults: DefaultPreferences()
        )

        let expansion = SourceExpansionResult(
            sourceKind: .playlistURL,
            sourceURL: "https://youtube.com/playlist?list=PL999",
            playlistMetadata: PlaylistMetadata(
                title: "RC Playlist",
                sourceURL: "https://youtube.com/playlist?list=PL999",
                entryCount: 2,
                extractor: "youtube",
                thumbnailURL: nil
            ),
            status: .ready,
            expandedItems: [
                ExpandedSourceItem(displayTitle: "Item 1", sourceURL: "https://youtube.com/watch?v=1", originalIndex: 0, isSelected: true, isValid: true),
                ExpandedSourceItem(displayTitle: "Item 2", sourceURL: "https://youtube.com/watch?v=2", originalIndex: 1, isSelected: true, isValid: true)
            ],
            skippedItems: []
        )

        let request = try mapper.mapToBatchCreationRequest(
            expansionResult: expansion,
            operationTemplate: template,
            preferredTitle: "Playlist Batch"
        )
        let batch = try await batchCreation.createBatch(request: request)

        let storedBatch = await repository.batch(id: batch.id)
        let storedItems = await repository.items(forBatchID: batch.id)

        XCTAssertEqual(storedItems.count, 2)
        XCTAssertEqual(storedBatch?.sourceDescriptor, "playlist:RC Playlist")
        XCTAssertNotNil(storedBatch?.sourceMetadataJSON)
    }
}
