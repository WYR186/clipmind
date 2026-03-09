import XCTest
@testable import VideoWorkspace

final class TaskProgressUpdateTests: XCTestCase {
    func testTaskCoordinatorStoresOutputPathAndHistory() async {
        let taskRepository = InMemoryTaskRepository()
        let historyRepository = InMemoryHistoryRepository()
        let coordinator = TaskExecutionCoordinator(
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            logger: ConsoleLogger(),
            notificationService: MockNotificationService(logger: ConsoleLogger())
        )

        var task = TaskItem(source: MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"), taskType: .export)
        await coordinator.addTask(task)

        task = await coordinator.updateTask(
            task,
            status: .running,
            progress: TaskProgressFactory.step(0.5, description: "Downloading")
        )

        let result = MediaDownloadResult(
            kind: .video,
            outputPath: "/tmp/sample.mp4",
            outputFileName: "sample.mp4"
        )
        await coordinator.completeTask(task, transcript: nil, summary: nil, downloadResult: result)

        let storedTask = await taskRepository.task(id: task.id)
        XCTAssertEqual(storedTask?.status, .completed)
        XCTAssertEqual(storedTask?.outputPath, "/tmp/sample.mp4")

        let entries = await historyRepository.allHistoryEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.downloadResult?.outputPath, "/tmp/sample.mp4")
    }
}
