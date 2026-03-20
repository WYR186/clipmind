import XCTest
@testable import VideoWorkspace

final class BatchCreationServiceTests: XCTestCase {
    func testCreateBatchFromURLsDeduplicatesAndFiltersInvalidInputs() async throws {
        let repository = InMemoryBatchJobRepository()
        let service = BatchCreationService(batchRepository: repository, logger: ConsoleLogger())
        let template = BatchOperationTemplate.fromDefaults(
            operationType: .exportAudio,
            defaults: DefaultPreferences()
        )

        let request = BatchCreationRequest(
            title: nil,
            sourceType: .urlBatch,
            sources: [
                MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"),
                MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"),
                MediaSource(type: .url, value: "   "),
                MediaSource(type: .url, value: "invalid-url"),
                MediaSource(type: .url, value: "https://bilibili.com/video/BV1XX")
            ],
            operationTemplate: template
        )

        let batch = try await service.createBatch(request: request)
        let items = await repository.items(forBatchID: batch.id)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(batch.totalCount, 2)
        XCTAssertEqual(Set(items.map { $0.source.value }).count, 2)
    }

    func testCreateBatchFromLocalFilesDeduplicatesPaths() async throws {
        let repository = InMemoryBatchJobRepository()
        let service = BatchCreationService(batchRepository: repository, logger: ConsoleLogger())
        let template = BatchOperationTemplate.fromDefaults(
            operationType: .transcribe,
            defaults: DefaultPreferences()
        )

        let request = BatchCreationRequest(
            title: "Local Batch",
            sourceType: .localFilesBatch,
            sources: [
                MediaSource(type: .localFile, value: "/tmp/a.mp4"),
                MediaSource(type: .localFile, value: "/tmp/a.mp4"),
                MediaSource(type: .localFile, value: "/tmp/b.mp4")
            ],
            operationTemplate: template
        )

        let batch = try await service.createBatch(request: request)
        let items = await repository.items(forBatchID: batch.id)

        XCTAssertEqual(batch.title, "Local Batch")
        XCTAssertEqual(items.count, 2)
    }

    func testCreateBatchThrowsWhenAllInputsInvalid() async {
        let repository = InMemoryBatchJobRepository()
        let service = BatchCreationService(batchRepository: repository, logger: ConsoleLogger())
        let template = BatchOperationTemplate.fromDefaults(
            operationType: .exportAudio,
            defaults: DefaultPreferences()
        )

        let request = BatchCreationRequest(
            title: nil,
            sourceType: .urlBatch,
            sources: [
                MediaSource(type: .url, value: "hello"),
                MediaSource(type: .url, value: "")
            ],
            operationTemplate: template
        )

        do {
            _ = try await service.createBatch(request: request)
            XCTFail("Expected createBatch to throw")
        } catch {
            XCTAssertTrue(error is BatchCreationError)
        }
    }
}
