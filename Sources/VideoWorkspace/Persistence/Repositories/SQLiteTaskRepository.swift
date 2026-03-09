import Foundation

actor SQLiteTaskRepository: TaskRepositoryProtocol {
    private let databaseManager: DatabaseManager
    private let logger: any AppLoggerProtocol
    private var continuations: [UUID: AsyncStream<[TaskItem]>.Continuation] = [:]

    init(databaseManager: DatabaseManager, logger: any AppLoggerProtocol) {
        self.databaseManager = databaseManager
        self.logger = logger
    }

    func addTask(_ task: TaskItem) async {
        await save(task)
    }

    func updateTask(_ task: TaskItem) async {
        await save(task)
    }

    func task(id: UUID) async -> TaskItem? {
        do {
            let rows = try await databaseManager.query(
                sql: TaskSQL.selectByID,
                bindings: [.text(id.uuidString)]
            )
            return rows.first.flatMap(decodeTask(from:))
        } catch {
            logger.error("TaskRepository read failed (id=\(id)): \(error.localizedDescription)")
            return nil
        }
    }

    func allTasks() async -> [TaskItem] {
        await fetchTasks()
    }

    func taskStream() async -> AsyncStream<[TaskItem]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { [weak self] in
                await self?.register(continuation: continuation, token: token)
            }
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(token: token)
                }
            }
        }
    }

    private func save(_ task: TaskItem) async {
        do {
            try await databaseManager.execute(
                sql: TaskSQL.upsert,
                bindings: upsertBindings(task: task)
            )
            await publish()
        } catch {
            logger.error("TaskRepository write failed (id=\(task.id)): \(error.localizedDescription)")
        }
    }

    private func fetchTasks() async -> [TaskItem] {
        do {
            let rows = try await databaseManager.query(sql: TaskSQL.selectAll)
            return rows.compactMap(decodeTask(from:))
        } catch {
            logger.error("TaskRepository allTasks failed: \(error.localizedDescription)")
            return []
        }
    }

    private func register(continuation: AsyncStream<[TaskItem]>.Continuation, token: UUID) async {
        continuations[token] = continuation
        continuation.yield(await fetchTasks())
    }

    private func removeContinuation(token: UUID) {
        continuations[token] = nil
    }

    private func publish() async {
        let snapshot = await fetchTasks()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func upsertBindings(task: TaskItem) -> [SQLiteBinding] {
        [
            .text(task.id.uuidString),
            .text(task.taskType.rawValue),
            .text(task.status.rawValue),
            .double(task.progress.fractionCompleted),
            .text(task.progress.currentStep),
            .text(task.source.type.rawValue),
            .text(task.source.value),
            .double(task.createdAt.timeIntervalSince1970),
            .double(task.updatedAt.timeIntervalSince1970),
            task.outputPath.map(SQLiteBinding.text) ?? .null,
            task.error?.code.map(SQLiteBinding.text) ?? .null,
            task.error?.message.map(SQLiteBinding.text) ?? .null,
            task.error?.technicalDetails.map(SQLiteBinding.text) ?? .null
        ]
    }

    private func decodeTask(from row: SQLiteRow) -> TaskItem? {
        guard
            let idRaw = row.text("id"),
            let id = UUID(uuidString: idRaw),
            let sourceTypeRaw = row.text("source_type"),
            let sourceType = SourceType(rawValue: sourceTypeRaw),
            let taskTypeRaw = row.text("task_type"),
            let taskType = TaskType(rawValue: taskTypeRaw),
            let statusRaw = row.text("status"),
            let status = TaskStatus(rawValue: statusRaw),
            let progressFraction = row.double("progress_fraction"),
            let progressStep = row.text("progress_step"),
            let createdAt = row.double("created_at"),
            let updatedAt = row.double("updated_at"),
            let sourceValue = row.text("source_value")
        else {
            return nil
        }

        let errorCode = row.text("error_code")
        let errorMessage = row.text("error_message")
        let technical = row.text("error_technical_details")

        let error: TaskError?
        if let errorCode, let errorMessage {
            error = TaskError(code: errorCode, message: errorMessage, technicalDetails: technical)
        } else {
            error = nil
        }

        return TaskItem(
            id: id,
            source: MediaSource(type: sourceType, value: sourceValue),
            taskType: taskType,
            status: status,
            progress: TaskProgress(fractionCompleted: progressFraction, currentStep: progressStep),
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            outputPath: row.text("output_path"),
            error: error
        )
    }
}
