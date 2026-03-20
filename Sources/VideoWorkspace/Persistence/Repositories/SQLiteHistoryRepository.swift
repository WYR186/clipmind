import Foundation

actor SQLiteHistoryRepository: HistoryRepositoryProtocol {
    private let databaseManager: DatabaseManager
    private let transcriptRepository: any TranscriptRepositoryProtocol
    private let summaryRepository: any SummaryRepositoryProtocol
    private let translationRepository: any TranslationRepositoryProtocol
    private let logger: any AppLoggerProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var continuations: [UUID: AsyncStream<[HistoryEntry]>.Continuation] = [:]

    init(
        databaseManager: DatabaseManager,
        transcriptRepository: any TranscriptRepositoryProtocol,
        summaryRepository: any SummaryRepositoryProtocol,
        translationRepository: any TranslationRepositoryProtocol,
        logger: any AppLoggerProtocol
    ) {
        self.databaseManager = databaseManager
        self.transcriptRepository = transcriptRepository
        self.summaryRepository = summaryRepository
        self.translationRepository = translationRepository
        self.logger = logger
    }

    func addHistoryEntry(_ entry: HistoryEntry) async {
        if let transcript = entry.transcript {
            await transcriptRepository.upsertTranscript(transcript, historyID: entry.id)
        }

        if let summary = entry.summary {
            await summaryRepository.upsertSummary(summary, historyID: entry.id)
        }

        if let translation = entry.translation {
            await translationRepository.upsertTranslation(translation, historyID: entry.id)
        }

        do {
            let previewText = makePreviewText(entry: entry)
            let title = makeTitle(entry: entry)
            let downloadJSON = try encodeJSON(entry.downloadResult)
            let taskBinding: SQLiteBinding = entry.taskID.map { .text($0.uuidString) } ?? .null
            let transcriptBinding: SQLiteBinding = entry.transcript.map { .text($0.id.uuidString) } ?? .null
            let summaryBinding: SQLiteBinding = entry.summary.map { .text($0.id.uuidString) } ?? .null
            let translationBinding: SQLiteBinding = entry.translation.map { .text($0.id.uuidString) } ?? .null
            let downloadBinding: SQLiteBinding = downloadJSON.map { .text($0) } ?? .null
            let backendRaw = entry.transcript?.backend?.rawValue
            let backendBinding: SQLiteBinding = backendRaw.map { .text($0) } ?? .null
            let providerRaw = entry.summary?.provider.rawValue ?? entry.translation?.provider.rawValue
            let providerBinding: SQLiteBinding = providerRaw.map { .text($0) } ?? .null
            let preferredModelID = entry.translation?.modelID ?? entry.summary?.modelID ?? entry.transcript?.modelID
            let modelBinding: SQLiteBinding = preferredModelID.map { .text($0) } ?? .null

            let bindings: [SQLiteBinding] = [
                .text(entry.id.uuidString),
                taskBinding,
                .text(entry.taskType.rawValue),
                .text(title),
                .text(entry.source.type.rawValue),
                .text(entry.source.value),
                .text(entry.source.value),
                transcriptBinding,
                summaryBinding,
                translationBinding,
                downloadBinding,
                .text(previewText),
                backendBinding,
                providerBinding,
                modelBinding,
                .double(entry.createdAt.timeIntervalSince1970)
            ]

            try await databaseManager.execute(sql: HistorySQL.upsert, bindings: bindings)
            await publish()
        } catch {
            logger.error("HistoryRepository write failed (id=\(entry.id)): \(error.localizedDescription)")
        }
    }

    func allHistoryEntries() async -> [HistoryEntry] {
        await fetchHistoryEntries()
    }

    func historyStream() async -> AsyncStream<[HistoryEntry]> {
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

    private func register(continuation: AsyncStream<[HistoryEntry]>.Continuation, token: UUID) async {
        continuations[token] = continuation
        continuation.yield(await fetchHistoryEntries())
    }

    private func removeContinuation(token: UUID) {
        continuations[token] = nil
    }

    private func publish() async {
        let snapshot = await fetchHistoryEntries()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func fetchHistoryEntries() async -> [HistoryEntry] {
        do {
            let rows = try await databaseManager.query(sql: HistorySQL.selectAll)
            var entries: [HistoryEntry] = []
            entries.reserveCapacity(rows.count)

            for row in rows {
                if let entry = await decodeHistoryEntry(from: row) {
                    entries.append(entry)
                }
            }
            return entries
        } catch {
            logger.error("HistoryRepository read failed: \(error.localizedDescription)")
            return []
        }
    }

    private func decodeHistoryEntry(from row: SQLiteRow) async -> HistoryEntry? {
        guard
            let idRaw = row.text("id"),
            let id = UUID(uuidString: idRaw),
            let taskTypeRaw = row.text("history_type"),
            let taskType = TaskType(rawValue: taskTypeRaw),
            let sourceTypeRaw = row.text("source_type"),
            let sourceType = SourceType(rawValue: sourceTypeRaw),
            let sourceValue = row.text("source_value"),
            let createdAtRaw = row.double("created_at")
        else {
            return nil
        }

        let taskID = row.text("related_task_id").flatMap(UUID.init(uuidString:))
        let transcriptID = row.text("transcript_id").flatMap(UUID.init(uuidString:))
        let summaryID = row.text("summary_id").flatMap(UUID.init(uuidString:))
        let translationID = row.text("translation_id").flatMap(UUID.init(uuidString:))

        let transcript = await transcriptID.flatMapAsync { id in
            await transcriptRepository.transcript(id: id)
        }
        let summary = await summaryID.flatMapAsync { id in
            await summaryRepository.summary(id: id)
        }
        let translation = await translationID.flatMapAsync { id in
            await translationRepository.translation(id: id)
        }

        let downloadResult: MediaDownloadResult?
        if let raw = row.text("download_result_json") {
            downloadResult = decodeJSON(raw)
        } else {
            downloadResult = nil
        }

        return HistoryEntry(
            id: id,
            taskID: taskID,
            source: MediaSource(type: sourceType, value: sourceValue),
            taskType: taskType,
            transcript: transcript,
            summary: summary,
            translation: translation,
            downloadResult: downloadResult,
            createdAt: Date(timeIntervalSince1970: createdAtRaw)
        )
    }

    private func makeTitle(entry: HistoryEntry) -> String {
        switch entry.source.type {
        case .url:
            return entry.source.value
        case .localFile:
            return URL(fileURLWithPath: entry.source.value).lastPathComponent
        }
    }

    private func makePreviewText(entry: HistoryEntry) -> String {
        if let summary = entry.summary, !summary.content.isEmpty {
            return String(summary.content.prefix(160))
        }
        if let translation = entry.translation, !translation.translatedText.isEmpty {
            return String(translation.translatedText.prefix(160))
        }
        if let transcript = entry.transcript, !transcript.content.isEmpty {
            return String(transcript.content.prefix(160))
        }
        if let downloadResult = entry.downloadResult {
            return downloadResult.outputPath
        }
        return entry.source.value
    }

    private func encodeJSON<T: Encodable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.repositoryWriteFailed(repository: "history", details: "Invalid UTF-8 JSON payload")
        }
        return string
    }

    private func decodeJSON<T: Decodable>(_ raw: String) -> T? {
        guard let data = raw.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }
}

private extension Optional {
    func flatMapAsync<T>(_ transform: (Wrapped) async -> T?) async -> T? {
        guard let value = self else { return nil }
        return await transform(value)
    }
}
