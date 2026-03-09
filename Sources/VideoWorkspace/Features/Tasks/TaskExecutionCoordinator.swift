import Foundation

struct TaskExecutionCoordinator {
    let taskRepository: any TaskRepositoryProtocol
    let historyRepository: any HistoryRepositoryProtocol
    let logger: any AppLoggerProtocol
    let notificationService: any NotificationServiceProtocol

    func addTask(_ task: TaskItem) async {
        await taskRepository.addTask(task)
        logger.debug("Task created: \(task.id)")
    }

    func updateTask(
        _ task: TaskItem,
        status: TaskStatus,
        progress: TaskProgress,
        outputPath: String? = nil,
        error: TaskError? = nil
    ) async -> TaskItem {
        var mutable = task
        mutable.status = status
        mutable.progress = progress
        if let outputPath {
            mutable.outputPath = outputPath
        }
        mutable.error = error
        mutable.updatedAt = Date()
        await taskRepository.updateTask(mutable)
        return mutable
    }

    func completeTask(
        _ task: TaskItem,
        transcript: TranscriptItem?,
        summary: SummaryResult?,
        downloadResult: MediaDownloadResult? = nil,
        outputPath: String? = nil
    ) async {
        let completed = await updateTask(
            task,
            status: .completed,
            progress: TaskProgressFactory.step(1, description: "Completed"),
            outputPath: outputPath ?? downloadResult?.outputPath
        )

        let entry = HistoryEntry(
            source: completed.source,
            taskType: completed.taskType,
            transcript: transcript,
            summary: summary,
            downloadResult: downloadResult
        )
        await historyRepository.addHistoryEntry(entry)

        await notificationService.notify(AppNotificationMessage(
            title: "Task Completed",
            body: "\(completed.taskType.rawValue.capitalized) finished"
        ))
    }

    func failTask(_ task: TaskItem, error: TaskError) async {
        _ = await updateTask(
            task,
            status: .failed,
            progress: TaskProgressFactory.step(task.progress.fractionCompleted, description: "Failed"),
            error: error
        )
        logger.error("Task failed: \(task.id) - \(error.message)")
    }
}
