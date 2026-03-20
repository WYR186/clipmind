import Foundation

actor SQLiteBatchJobRepository: BatchJobRepositoryProtocol {
    private let databaseManager: DatabaseManager
    private let logger: any AppLoggerProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var batchContinuations: [UUID: AsyncStream<[BatchJob]>.Continuation] = [:]
    private var itemContinuationsByBatchID: [BatchJobID: [UUID: AsyncStream<[BatchJobItem]>.Continuation]] = [:]
    private var didRecoverInterruptedStates = false

    init(databaseManager: DatabaseManager, logger: any AppLoggerProtocol) {
        self.databaseManager = databaseManager
        self.logger = logger
    }

    func createBatch(job: BatchJob, items: [BatchJobItem]) async {
        await ensureInterruptedRecoveryIfNeeded()
        do {
            var operations: [SQLiteOperation] = [upsertBatchOperation(job)]
            operations.append(contentsOf: items.map(upsertItemOperation))
            try await databaseManager.runTransaction(operations)
            await publishBatches()
            await publishItems(for: job.id)
        } catch {
            logger.error("BatchRepository create failed (id=\(job.id)): \(error.localizedDescription)")
        }
    }

    func updateBatch(_ job: BatchJob) async {
        await ensureInterruptedRecoveryIfNeeded()
        do {
            try await databaseManager.execute(
                sql: BatchSQL.upsertBatch,
                bindings: batchBindings(job)
            )
            await publishBatches()
        } catch {
            logger.error("BatchRepository batch update failed (id=\(job.id)): \(error.localizedDescription)")
        }
    }

    func updateItem(_ item: BatchJobItem) async {
        await ensureInterruptedRecoveryIfNeeded()
        do {
            try await databaseManager.execute(
                sql: BatchSQL.upsertItem,
                bindings: itemBindings(item)
            )
            await publishItems(for: item.batchJobID)
            await publishBatches()
        } catch {
            logger.error("BatchRepository item update failed (id=\(item.id)): \(error.localizedDescription)")
        }
    }

    func batch(id: BatchJobID) async -> BatchJob? {
        await ensureInterruptedRecoveryIfNeeded()
        do {
            let rows = try await databaseManager.query(
                sql: BatchSQL.selectBatchByID,
                bindings: [.text(id.uuidString)]
            )
            return rows.first.flatMap(decodeBatch)
        } catch {
            logger.error("BatchRepository read failed (id=\(id)): \(error.localizedDescription)")
            return nil
        }
    }

    func items(forBatchID batchID: BatchJobID) async -> [BatchJobItem] {
        await ensureInterruptedRecoveryIfNeeded()
        do {
            let rows = try await databaseManager.query(
                sql: BatchSQL.selectItemsByBatchID,
                bindings: [.text(batchID.uuidString)]
            )
            return rows.compactMap(decodeItem)
        } catch {
            logger.error("BatchRepository items read failed (batch=\(batchID)): \(error.localizedDescription)")
            return []
        }
    }

    func allBatches() async -> [BatchJob] {
        await ensureInterruptedRecoveryIfNeeded()
        return await fetchBatches()
    }

    func batchStream() async -> AsyncStream<[BatchJob]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { [weak self] in
                await self?.registerBatchContinuation(continuation, token: token)
            }

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeBatchContinuation(token: token)
                }
            }
        }
    }

    func itemStream(forBatchID batchID: BatchJobID) async -> AsyncStream<[BatchJobItem]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { [weak self] in
                await self?.registerItemContinuation(continuation, token: token, batchID: batchID)
            }

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeItemContinuation(token: token, batchID: batchID)
                }
            }
        }
    }

    private func registerBatchContinuation(
        _ continuation: AsyncStream<[BatchJob]>.Continuation,
        token: UUID
    ) async {
        batchContinuations[token] = continuation
        continuation.yield(await fetchBatches())
    }

    private func removeBatchContinuation(token: UUID) {
        batchContinuations[token] = nil
    }

    private func registerItemContinuation(
        _ continuation: AsyncStream<[BatchJobItem]>.Continuation,
        token: UUID,
        batchID: BatchJobID
    ) async {
        var bucket = itemContinuationsByBatchID[batchID] ?? [:]
        bucket[token] = continuation
        itemContinuationsByBatchID[batchID] = bucket
        continuation.yield(await items(forBatchID: batchID))
    }

    private func removeItemContinuation(token: UUID, batchID: BatchJobID) {
        guard var bucket = itemContinuationsByBatchID[batchID] else {
            return
        }
        bucket[token] = nil
        if bucket.isEmpty {
            itemContinuationsByBatchID[batchID] = nil
        } else {
            itemContinuationsByBatchID[batchID] = bucket
        }
    }

    private func publishBatches() async {
        let snapshot = await fetchBatches()
        for continuation in batchContinuations.values {
            continuation.yield(snapshot)
        }
    }

    private func publishItems(for batchID: BatchJobID) async {
        guard let bucket = itemContinuationsByBatchID[batchID], !bucket.isEmpty else {
            return
        }
        let snapshot = await items(forBatchID: batchID)
        for continuation in bucket.values {
            continuation.yield(snapshot)
        }
    }

    private func fetchBatches() async -> [BatchJob] {
        do {
            let rows = try await databaseManager.query(sql: BatchSQL.selectAllBatches)
            return rows.compactMap(decodeBatch)
        } catch {
            logger.error("BatchRepository allBatches failed: \(error.localizedDescription)")
            return []
        }
    }

    private func ensureInterruptedRecoveryIfNeeded() async {
        guard !didRecoverInterruptedStates else {
            return
        }

        do {
            let now = Date().timeIntervalSince1970
            try await databaseManager.runTransaction([
                SQLiteOperation(
                    sql: BatchSQL.markRunningItemsInterrupted,
                    bindings: [.double(now)]
                ),
                SQLiteOperation(
                    sql: BatchSQL.markRunningBatchesInterrupted,
                    bindings: [.double(now)]
                )
            ])
            didRecoverInterruptedStates = true
        } catch {
            logger.error("BatchRepository interrupted recovery failed: \(error.localizedDescription)")
            didRecoverInterruptedStates = true
        }
    }

    private func upsertBatchOperation(_ batch: BatchJob) -> SQLiteOperation {
        SQLiteOperation(sql: BatchSQL.upsertBatch, bindings: batchBindings(batch))
    }

    private func upsertItemOperation(_ item: BatchJobItem) -> SQLiteOperation {
        SQLiteOperation(sql: BatchSQL.upsertItem, bindings: itemBindings(item))
    }

    private func batchBindings(_ batch: BatchJob) -> [SQLiteBinding] {
        let templateData = (try? encoder.encode(batch.operationTemplate)) ?? Data("{}".utf8)
        let tasksData = (try? encoder.encode(batch.childTaskIDs.map(\.uuidString))) ?? Data("[]".utf8)
        let templatePayload = String(data: templateData, encoding: .utf8) ?? "{}"
        let tasksPayload = String(data: tasksData, encoding: .utf8) ?? "[]"

        return [
            .text(batch.id.uuidString),
            .text(batch.title),
            .text(batch.sourceType.rawValue),
            batch.sourceDescriptor.map(SQLiteBinding.text) ?? .null,
            batch.sourceMetadataJSON.map(SQLiteBinding.text) ?? .null,
            .text(batch.status.rawValue),
            .double(batch.progress.fractionCompleted),
            .integer(Int64(batch.progress.totalCount)),
            .integer(Int64(batch.progress.completedCount)),
            .integer(Int64(batch.progress.failedCount)),
            .integer(Int64(batch.progress.runningCount)),
            .integer(Int64(batch.progress.pendingCount)),
            .integer(Int64(batch.progress.cancelledCount)),
            .text(templatePayload),
            .text(tasksPayload),
            batch.lastErrorSummary.map(SQLiteBinding.text) ?? .null,
            .double(batch.createdAt.timeIntervalSince1970),
            .double(batch.updatedAt.timeIntervalSince1970)
        ]
    }

    private func itemBindings(_ item: BatchJobItem) -> [SQLiteBinding] {
        [
            .text(item.id.uuidString),
            .text(item.batchJobID.uuidString),
            .text(item.source.type.rawValue),
            .text(item.source.value),
            item.taskID.map { .text($0.uuidString) } ?? .null,
            .text(item.status.rawValue),
            .double(item.progress),
            .double(item.createdAt.timeIntervalSince1970),
            .double(item.updatedAt.timeIntervalSince1970),
            item.failureReason.map(SQLiteBinding.text) ?? .null,
            item.errorCode.map(SQLiteBinding.text) ?? .null
        ]
    }

    private func decodeBatch(from row: SQLiteRow) -> BatchJob? {
        guard
            let idRaw = row.text("id"),
            let id = UUID(uuidString: idRaw),
            let title = row.text("title"),
            let sourceTypeRaw = row.text("source_type"),
            let sourceType = BatchSourceType(rawValue: sourceTypeRaw),
            let statusRaw = row.text("status"),
            let status = BatchJobStatus(rawValue: statusRaw),
            let fraction = row.double("progress_fraction"),
            let totalCount = row.integer("total_count"),
            let completedCount = row.integer("completed_count"),
            let failedCount = row.integer("failed_count"),
            let runningCount = row.integer("running_count"),
            let pendingCount = row.integer("pending_count"),
            let cancelledCount = row.integer("cancelled_count"),
            let templateJSON = row.text("operation_template_json"),
            let createdAtRaw = row.double("created_at"),
            let updatedAtRaw = row.double("updated_at")
        else {
            return nil
        }

        guard
            let templateData = templateJSON.data(using: .utf8),
            let template = try? decoder.decode(BatchOperationTemplate.self, from: templateData)
        else {
            return nil
        }

        let childTaskIDs: [UUID] = {
            guard let raw = row.text("child_task_ids_json"), let data = raw.data(using: .utf8) else {
                return []
            }
            guard let values = try? decoder.decode([String].self, from: data) else {
                return []
            }
            return values.compactMap(UUID.init(uuidString:))
        }()

        return BatchJob(
            id: id,
            title: title,
            sourceType: sourceType,
            createdAt: Date(timeIntervalSince1970: createdAtRaw),
            updatedAt: Date(timeIntervalSince1970: updatedAtRaw),
            status: status,
            progress: BatchJobProgress(
                totalCount: Int(totalCount),
                completedCount: Int(completedCount),
                failedCount: Int(failedCount),
                runningCount: Int(runningCount),
                pendingCount: Int(pendingCount),
                cancelledCount: Int(cancelledCount),
                fractionCompleted: fraction
            ),
            operationTemplate: template,
            childTaskIDs: childTaskIDs,
            lastErrorSummary: row.text("last_error_summary"),
            sourceDescriptor: row.text("source_descriptor"),
            sourceMetadataJSON: row.text("source_metadata_json")
        )
    }

    private func decodeItem(from row: SQLiteRow) -> BatchJobItem? {
        guard
            let idRaw = row.text("id"),
            let id = UUID(uuidString: idRaw),
            let batchRaw = row.text("batch_job_id"),
            let batchID = UUID(uuidString: batchRaw),
            let sourceTypeRaw = row.text("source_type"),
            let sourceType = SourceType(rawValue: sourceTypeRaw),
            let sourceValue = row.text("source_value"),
            let statusRaw = row.text("status"),
            let status = BatchJobItemStatus(rawValue: statusRaw),
            let progress = row.double("progress_fraction"),
            let createdAtRaw = row.double("created_at"),
            let updatedAtRaw = row.double("updated_at")
        else {
            return nil
        }

        return BatchJobItem(
            id: id,
            batchJobID: batchID,
            source: MediaSource(type: sourceType, value: sourceValue),
            taskID: row.text("task_id").flatMap(UUID.init(uuidString:)),
            status: status,
            progress: progress,
            createdAt: Date(timeIntervalSince1970: createdAtRaw),
            updatedAt: Date(timeIntervalSince1970: updatedAtRaw),
            failureReason: row.text("failure_reason"),
            errorCode: row.text("error_code")
        )
    }
}
