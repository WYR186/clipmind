import XCTest
@testable import VideoWorkspace

final class SQLiteArtifactRepositoryTests: XCTestCase {
    func testQueryArtifactsByTaskHistoryAndType() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "sqlite-artifacts")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let logger = ConsoleLogger()
        let manager = try DatabaseManager(configuration: configuration, logger: logger)
        let repository = SQLiteArtifactRepository(databaseManager: manager, logger: logger)

        let taskID = UUID()
        let historyID = UUID()

        let artifacts = [
            ArtifactRecord(
                ownerType: .download,
                ownerID: historyID,
                relatedTaskID: taskID,
                relatedHistoryID: historyID,
                artifactType: .downloadAudio,
                filePath: "/tmp/a.m4a",
                fileFormat: "m4a"
            ),
            ArtifactRecord(
                ownerType: .transcript,
                ownerID: UUID(),
                relatedTaskID: taskID,
                relatedHistoryID: historyID,
                artifactType: .transcriptTXT,
                filePath: "/tmp/a.txt",
                fileFormat: "txt"
            ),
            ArtifactRecord(
                ownerType: .summary,
                ownerID: UUID(),
                relatedTaskID: UUID(),
                relatedHistoryID: UUID(),
                artifactType: .summaryMarkdown,
                filePath: "/tmp/a.md",
                fileFormat: "md"
            )
        ]

        await repository.addArtifacts(artifacts)

        let byTask = await repository.artifacts(forTaskID: taskID)
        XCTAssertEqual(byTask.count, 2)

        let byHistory = await repository.artifacts(forHistoryID: historyID)
        XCTAssertEqual(byHistory.count, 2)

        let byType = await repository.artifacts(ofType: .transcriptTXT)
        XCTAssertEqual(byType.count, 1)
        XCTAssertEqual(byType.first?.fileFormat, "txt")
    }
}
