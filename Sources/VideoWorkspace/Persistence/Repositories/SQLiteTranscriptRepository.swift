import Foundation

actor SQLiteTranscriptRepository: TranscriptRepositoryProtocol {
    private let databaseManager: DatabaseManager
    private let logger: any AppLoggerProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(databaseManager: DatabaseManager, logger: any AppLoggerProtocol) {
        self.databaseManager = databaseManager
        self.logger = logger
    }

    func upsertTranscript(_ transcript: TranscriptItem, historyID: UUID?) async {
        do {
            let segments = try encodeJSON(transcript.segments)
            let artifacts = try encodeJSON(transcript.artifacts)

            try await databaseManager.execute(
                sql: TranscriptSQL.upsert,
                bindings: [
                    .text(transcript.id.uuidString),
                    .text(transcript.taskID.uuidString),
                    historyID.map { .text($0.uuidString) } ?? .null,
                    .text(transcript.sourceType.rawValue),
                    .text(transcript.languageCode),
                    .text(transcript.format.rawValue),
                    .text(transcript.content),
                    .text(segments),
                    .text(artifacts),
                    transcript.backend.map { .text($0.rawValue) } ?? .null,
                    transcript.modelID.map(SQLiteBinding.text) ?? .null,
                    transcript.detectedLanguage.map(SQLiteBinding.text) ?? .null,
                    transcript.artifacts.first.map { .text($0.path) } ?? .null,
                    .double(Date().timeIntervalSince1970),
                    .double(Date().timeIntervalSince1970)
                ]
            )
        } catch {
            logger.error("TranscriptRepository upsert failed (id=\(transcript.id)): \(error.localizedDescription)")
        }
    }

    func transcript(id: UUID) async -> TranscriptItem? {
        do {
            let rows = try await databaseManager.query(
                sql: TranscriptSQL.selectByID,
                bindings: [.text(id.uuidString)]
            )
            return rows.first.flatMap(decodeTranscript(from:))
        } catch {
            logger.error("TranscriptRepository read failed (id=\(id)): \(error.localizedDescription)")
            return nil
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.repositoryWriteFailed(repository: "transcripts", details: "Encoding produced invalid UTF-8")
        }
        return string
    }

    private func decodeTranscript(from row: SQLiteRow) -> TranscriptItem? {
        guard
            let idRaw = row.text("id"),
            let id = UUID(uuidString: idRaw),
            let taskIDRaw = row.text("task_id"),
            let taskID = UUID(uuidString: taskIDRaw),
            let sourceTypeRaw = row.text("source_type"),
            let sourceType = SubtitleSourceType(rawValue: sourceTypeRaw),
            let languageCode = row.text("language_code"),
            let formatRaw = row.text("format"),
            let format = TranscriptFormat(rawValue: formatRaw),
            let content = row.text("content")
        else {
            return nil
        }

        let segments: [TranscriptSegment] = decodeJSON(row.text("segments_json")) ?? []
        let artifacts: [TranscriptArtifact] = decodeJSON(row.text("artifacts_json")) ?? []

        return TranscriptItem(
            id: id,
            taskID: taskID,
            sourceType: sourceType,
            languageCode: languageCode,
            format: format,
            content: content,
            segments: segments,
            artifacts: artifacts,
            backend: row.text("backend").flatMap(TranscriptionBackend.init(rawValue:)),
            modelID: row.text("model_id"),
            detectedLanguage: row.text("detected_language")
        )
    }

    private func decodeJSON<T: Decodable>(_ raw: String?) -> T? {
        guard let raw, let data = raw.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }
}
