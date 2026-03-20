import XCTest
@testable import VideoWorkspace

final class SQLiteTaskRepositoryTests: XCTestCase {
    func testTaskCRUD() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "sqlite-task")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let logger = ConsoleLogger()
        let manager = try DatabaseManager(configuration: configuration, logger: logger)
        let repository = SQLiteTaskRepository(databaseManager: manager, logger: logger)

        let source = MediaSource(type: .localFile, value: "/tmp/demo.mp4")
        var task = TaskItem(source: source, taskType: .transcribe)

        await repository.addTask(task)
        var fetched = await repository.task(id: task.id)
        XCTAssertEqual(fetched?.taskType, .transcribe)
        XCTAssertEqual(fetched?.status, .queued)

        task.status = .running
        task.progress = TaskProgress(fractionCompleted: 0.6, currentStep: "Running")
        task.updatedAt = Date()
        await repository.updateTask(task)

        fetched = await repository.task(id: task.id)
        XCTAssertEqual(fetched?.status, .running)
        XCTAssertEqual(fetched?.progress.currentStep, "Running")

        let all = await repository.allTasks()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, task.id)
    }
}
