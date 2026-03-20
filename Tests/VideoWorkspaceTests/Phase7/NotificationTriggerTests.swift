import XCTest
@testable import VideoWorkspace

final class NotificationTriggerTests: XCTestCase {
    func testCoordinatorSendsCompletionAndFailureNotifications() async {
        let taskRepository = InMemoryTaskRepository()
        let historyRepository = InMemoryHistoryRepository()
        let notificationService = RecordingNotificationService()

        let coordinator = TaskExecutionCoordinator(
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            artifactIndexingService: nil,
            tempFileCleanupService: nil,
            logger: ConsoleLogger(),
            notificationService: notificationService
        )

        let task = TaskItem(source: MediaSource(type: .url, value: "https://example.com"), taskType: .export)
        await coordinator.addTask(task)
        await coordinator.completeTask(
            task,
            transcript: nil,
            summary: nil,
            downloadResult: MediaDownloadResult(kind: .video, outputPath: "/tmp/a.mp4", outputFileName: "a.mp4")
        )

        await coordinator.failTask(task, error: TaskError(code: "TEST_FAIL", message: "failed"))

        let messages = await notificationService.messages()
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages.first?.title, "Task Completed")
        XCTAssertEqual(messages.last?.title, "Task Failed")
    }
}

private actor RecordingNotificationService: NotificationServiceProtocol {
    private var storage: [AppNotificationMessage] = []

    func requestAuthorization() async {}

    func notify(_ message: AppNotificationMessage) async {
        storage.append(message)
    }

    func messages() -> [AppNotificationMessage] {
        storage
    }
}
