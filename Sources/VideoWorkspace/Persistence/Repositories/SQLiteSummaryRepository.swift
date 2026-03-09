import Foundation

actor SQLiteSummaryRepository: SummaryRepositoryProtocol {
    private let databaseManager: DatabaseManager
    private let logger: any AppLoggerProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(databaseManager: DatabaseManager, logger: any AppLoggerProtocol) {
        self.databaseManager = databaseManager
        self.logger = logger
    }

    func upsertSummary(_ summary: SummaryResult, historyID: UUID?) async {
        do {
            let structuredJSON = try encodeJSON(summary.structured)
            let artifactsJSON = try encodeJSON(summary.artifacts)

            try await databaseManager.execute(
                sql: SummarySQL.upsert,
                bindings: [
                    .text(summary.id.uuidString),
                    .text(summary.taskID.uuidString),
                    historyID.map { .text($0.uuidString) } ?? .null,
                    .text(summary.provider.rawValue),
                    .text(summary.modelID),
                    summary.templateKind.map { .text($0.rawValue) } ?? .null,
                    summary.outputLanguage.map(SQLiteBinding.text) ?? .null,
                    .text(summary.mode.rawValue),
                    .text(summary.length.rawValue),
                    .text(summary.content),
                    structuredJSON.map(SQLiteBinding.text) ?? .null,
                    summary.markdown.map(SQLiteBinding.text) ?? .null,
                    summary.plainText.map(SQLiteBinding.text) ?? .null,
                    .text(artifactsJSON),
                    summary.artifacts.first.map { .text($0.path) } ?? .null,
                    .double(summary.createdAt.timeIntervalSince1970)
                ]
            )
        } catch {
            logger.error("SummaryRepository upsert failed (id=\(summary.id)): \(error.localizedDescription)")
        }
    }

    func summary(id: UUID) async -> SummaryResult? {
        do {
            let rows = try await databaseManager.query(
                sql: SummarySQL.selectByID,
                bindings: [.text(id.uuidString)]
            )
            return rows.first.flatMap(decodeSummary(from:))
        } catch {
            logger.error("SummaryRepository read failed (id=\(id)): \(error.localizedDescription)")
            return nil
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.repositoryWriteFailed(repository: "summaries", details: "Encoding produced invalid UTF-8")
        }
        return string
    }

    private func decodeSummary(from row: SQLiteRow) -> SummaryResult? {
        guard
            let idRaw = row.text("id"),
            let id = UUID(uuidString: idRaw),
            let taskIDRaw = row.text("task_id"),
            let taskID = UUID(uuidString: taskIDRaw),
            let providerRaw = row.text("provider"),
            let provider = ProviderType(rawValue: providerRaw),
            let modelID = row.text("model_id"),
            let modeRaw = row.text("mode"),
            let mode = SummaryMode(rawValue: modeRaw),
            let lengthRaw = row.text("length"),
            let length = SummaryLength(rawValue: lengthRaw),
            let content = row.text("content")
        else {
            return nil
        }

        let structured: StructuredSummaryPayload? = decodeJSON(row.text("structured_json"))
        let artifacts: [SummaryArtifact] = decodeJSON(row.text("artifacts_json")) ?? []

        let createdAt = row.double("created_at").map(Date.init(timeIntervalSince1970:)) ?? Date()

        return SummaryResult(
            id: id,
            taskID: taskID,
            provider: provider,
            modelID: modelID,
            mode: mode,
            length: length,
            content: content,
            structured: structured,
            markdown: row.text("markdown"),
            plainText: row.text("plain_text"),
            artifacts: artifacts,
            templateKind: row.text("template_kind").flatMap(SummaryPromptTemplateKind.init(rawValue:)),
            outputLanguage: row.text("output_language"),
            diagnostics: nil,
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
