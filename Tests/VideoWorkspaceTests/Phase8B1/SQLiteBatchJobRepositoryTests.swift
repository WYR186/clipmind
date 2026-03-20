import XCTest
@testable import VideoWorkspace

final class SQLiteBatchJobRepositoryTests: XCTestCase {
    func testBatchCRUDAndItemRestore() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "sqlite-batch")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let manager = try DatabaseManager(configuration: configuration, logger: ConsoleLogger())
        let repository = SQLiteBatchJobRepository(databaseManager: manager, logger: ConsoleLogger())

        let template = BatchOperationTemplate.fromDefaults(
            operationType: .transcribe,
            defaults: DefaultPreferences()
        )
        let batch = BatchJob(
            title: "Batch",
            sourceType: .localFilesBatch,
            status: .queued,
            progress: BatchJobProgress(
                totalCount: 2,
                completedCount: 0,
                failedCount: 0,
                runningCount: 0,
                pendingCount: 2,
                cancelledCount: 0,
                fractionCompleted: 0
            ),
            operationTemplate: template,
            sourceDescriptor: "playlist:Demo",
            sourceMetadataJSON: "{\"title\":\"Demo\"}"
        )

        let items = [
            BatchJobItem(batchJobID: batch.id, source: MediaSource(type: .localFile, value: "/tmp/a.mp4")),
            BatchJobItem(batchJobID: batch.id, source: MediaSource(type: .localFile, value: "/tmp/b.mp4"))
        ]

        await repository.createBatch(job: batch, items: items)

        let fetched = await repository.batch(id: batch.id)
        let fetchedItems = await repository.items(forBatchID: batch.id)

        XCTAssertEqual(fetched?.title, "Batch")
        XCTAssertEqual(fetched?.sourceDescriptor, "playlist:Demo")
        XCTAssertEqual(fetched?.sourceMetadataJSON, "{\"title\":\"Demo\"}")
        XCTAssertEqual(fetchedItems.count, 2)
    }

    func testStartupRecoveryMarksRunningStateAsInterrupted() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "sqlite-batch-recover")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let template = BatchOperationTemplate.fromDefaults(
            operationType: .exportAudio,
            defaults: DefaultPreferences()
        )

        do {
            let manager = try DatabaseManager(configuration: configuration, logger: ConsoleLogger())
            let repository = SQLiteBatchJobRepository(databaseManager: manager, logger: ConsoleLogger())
            let runningBatch = BatchJob(
                title: "Recover",
                sourceType: .urlBatch,
                status: .running,
                progress: BatchJobProgress(
                    totalCount: 1,
                    completedCount: 0,
                    failedCount: 0,
                    runningCount: 1,
                    pendingCount: 0,
                    cancelledCount: 0,
                    fractionCompleted: 0.2
                ),
                operationTemplate: template
            )
            let runningItem = BatchJobItem(
                batchJobID: runningBatch.id,
                source: MediaSource(type: .url, value: "https://example.com/video"),
                status: .running,
                progress: 0.2
            )
            await repository.createBatch(job: runningBatch, items: [runningItem])
        }

        let newManager = try DatabaseManager(configuration: configuration, logger: ConsoleLogger())
        let recoveredRepository = SQLiteBatchJobRepository(databaseManager: newManager, logger: ConsoleLogger())
        let batches = await recoveredRepository.allBatches()
        guard let recovered = batches.first else {
            XCTFail("Missing recovered batch")
            return
        }

        let items = await recoveredRepository.items(forBatchID: recovered.id)
        XCTAssertEqual(recovered.status, .interrupted)
        XCTAssertEqual(items.first?.status, .interrupted)
    }
}
