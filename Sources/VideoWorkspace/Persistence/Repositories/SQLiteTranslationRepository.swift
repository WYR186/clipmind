import Foundation

actor SQLiteTranslationRepository: TranslationRepositoryProtocol {
    private let databaseManager: DatabaseManager
    private let logger: any AppLoggerProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(databaseManager: DatabaseManager, logger: any AppLoggerProtocol) {
        self.databaseManager = databaseManager
        self.logger = logger
    }

    func upsertTranslation(_ translation: TranslationResult, historyID: UUID?) async {
        do {
            let segmentsJSON = try encodeJSON(translation.segments)
            let artifactsJSON = try encodeJSON(translation.artifacts)

            let bindings: [SQLiteBinding] = [
                .text(translation.id.uuidString),
                .text(translation.taskID.uuidString),
                historyID.map { .text($0.uuidString) } ?? .null,
                translation.sourceTranscriptID.map { .text($0.uuidString) } ?? .null,
                .text(translation.provider.rawValue),
                .text(translation.modelID),
                .text(translation.languagePair.sourceLanguage),
                .text(translation.languagePair.targetLanguage),
                .text(translation.mode.rawValue),
                .text(translation.style.rawValue),
                .text(translation.translatedText),
                translation.bilingualText.map(SQLiteBinding.text) ?? .null,
                .text(segmentsJSON),
                .text(artifactsJSON),
                translation.diagnostics.map(SQLiteBinding.text) ?? .null,
                translation.artifacts.first.map { .text($0.path) } ?? .null,
                .double(translation.createdAt.timeIntervalSince1970)
            ]

            try await databaseManager.execute(sql: TranslationSQL.upsert, bindings: bindings)
        } catch {
            logger.error("TranslationRepository upsert failed (id=\(translation.id)): \(error.localizedDescription)")
        }
    }

    func translation(id: UUID) async -> TranslationResult? {
        do {
            let rows = try await databaseManager.query(
                sql: TranslationSQL.selectByID,
                bindings: [.text(id.uuidString)]
            )
            return rows.first.flatMap(decodeTranslation(from:))
        } catch {
            logger.error("TranslationRepository read failed (id=\(id)): \(error.localizedDescription)")
            return nil
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.repositoryWriteFailed(repository: "translations", details: "Encoding produced invalid UTF-8")
        }
        return string
    }

    private func decodeTranslation(from row: SQLiteRow) -> TranslationResult? {
        guard
            let idRaw = row.text("id"),
            let id = UUID(uuidString: idRaw),
            let taskRaw = row.text("task_id"),
            let taskID = UUID(uuidString: taskRaw),
            let providerRaw = row.text("provider"),
            let provider = ProviderType(rawValue: providerRaw),
            let modelID = row.text("model_id"),
            let sourceLanguage = row.text("source_language"),
            let targetLanguage = row.text("target_language"),
            let modeRaw = row.text("mode"),
            let mode = TranslationMode(rawValue: modeRaw),
            let styleRaw = row.text("style"),
            let style = TranslationStyle(rawValue: styleRaw),
            let translatedText = row.text("translated_text")
        else {
            return nil
        }

        let segments: [TranslationSegment] = decodeJSON(row.text("segments_json")) ?? []
        let artifacts: [TranslationArtifact] = decodeJSON(row.text("artifacts_json")) ?? []
        let createdAt = row.double("created_at").map(Date.init(timeIntervalSince1970:)) ?? Date()

        return TranslationResult(
            id: id,
            taskID: taskID,
            sourceTranscriptID: row.text("source_transcript_id").flatMap(UUID.init(uuidString:)),
            provider: provider,
            modelID: modelID,
            languagePair: TranslationLanguagePair(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage),
            mode: mode,
            style: style,
            translatedText: translatedText,
            bilingualText: row.text("bilingual_text"),
            segments: segments,
            artifacts: artifacts,
            diagnostics: row.text("diagnostics"),
            createdAt: createdAt
        )
    }

    private func decodeJSON<T: Decodable>(_ raw: String?) -> T? {
        guard let raw, let data = raw.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }
}
