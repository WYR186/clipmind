import XCTest
@testable import VideoWorkspace

final class InMemoryTaskRepositoryTests: XCTestCase {
    func testAddAndFetchTask() async {
        let repository = InMemoryTaskRepository()
        let source = MediaSource(type: .url, value: "https://example.com")
        let task = TaskItem(source: source, taskType: .inspect)

        await repository.addTask(task)
        let tasks = await repository.allTasks()

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, task.id)
    }

    func testUpdateTaskStatus() async {
        let repository = InMemoryTaskRepository()
        let source = MediaSource(type: .localFile, value: "/tmp/a.mp4")
        var task = TaskItem(source: source, taskType: .transcribe)

        await repository.addTask(task)
        task.status = .running
        task.progress = TaskProgressFactory.step(0.5, description: "Half")
        await repository.updateTask(task)

        let fetched = await repository.task(id: task.id)
        XCTAssertEqual(fetched?.status, .running)
        XCTAssertEqual(fetched?.progress.currentStep, "Half")
    }
}
