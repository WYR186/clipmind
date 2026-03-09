import Foundation

actor SQLiteArtifactRepository: ArtifactRepositoryProtocol {
    private let databaseManager: DatabaseManager
    private let logger: any AppLoggerProtocol

    init(databaseManager: DatabaseManager, logger: any AppLoggerProtocol) {
        self.databaseManager = databaseManager
        self.logger = logger
    }

    func addArtifacts(_ artifacts: [ArtifactRecord]) async {
        guard !artifacts.isEmpty else { return }

        let operations = artifacts.map { artifact in
            SQLiteOperation(sql: ArtifactSQL.upsert, bindings: upsertBindings(artifact))
        }

        do {
            try await databaseManager.runTransaction(operations)
        } catch {
            logger.error("ArtifactRepository write failed: \(error.localizedDescription)")
        }
    }

    func artifacts(forTaskID taskID: UUID) async -> [ArtifactRecord] {
        await queryArtifacts(sql: ArtifactSQL.selectByTaskID, binding: .text(taskID.uuidString))
    }

    func artifacts(forHistoryID historyID: UUID) async -> [ArtifactRecord] {
        await queryArtifacts(sql: ArtifactSQL.selectByHistoryID, binding: .text(historyID.uuidString))
    }

    func artifacts(ofType type: ArtifactType) async -> [ArtifactRecord] {
        await queryArtifacts(sql: ArtifactSQL.selectByType, binding: .text(type.rawValue))
    }

    private func queryArtifacts(sql: String, binding: SQLiteBinding) async -> [ArtifactRecord] {
        do {
            let rows = try await databaseManager.query(sql: sql, bindings: [binding])
            return rows.compactMap(decodeArtifact(from:))
        } catch {
            logger.error("ArtifactRepository read failed: \(error.localizedDescription)")
            return []
        }
    }

    private func upsertBindings(_ artifact: ArtifactRecord) -> [SQLiteBinding] {
        [
            .text(artifact.id.uuidString),
            .text(artifact.ownerType.rawValue),
            .text(artifact.ownerID.uuidString),
            artifact.relatedTaskID.map { .text($0.uuidString) } ?? .null,
            artifact.relatedHistoryID.map { .text($0.uuidString) } ?? .null,
            .text(artifact.artifactType.rawValue),
            .text(artifact.filePath),
            .text(artifact.fileFormat),
            artifact.sizeBytes.map(SQLiteBinding.integer) ?? .null,
            artifact.backend.map(SQLiteBinding.text) ?? .null,
            artifact.provider.map { .text($0.rawValue) } ?? .null,
            artifact.model.map(SQLiteBinding.text) ?? .null,
            .double(artifact.createdAt.timeIntervalSince1970)
        ]
    }

    private func decodeArtifact(from row: SQLiteRow) -> ArtifactRecord? {
        guard
            let idRaw = row.text("id"),
            let id = UUID(uuidString: idRaw),
            let ownerTypeRaw = row.text("owner_type"),
            let ownerType = ArtifactOwnerType(rawValue: ownerTypeRaw),
            let ownerIDRaw = row.text("owner_id"),
            let ownerID = UUID(uuidString: ownerIDRaw),
            let artifactTypeRaw = row.text("artifact_type"),
            let artifactType = ArtifactType(rawValue: artifactTypeRaw),
            let filePath = row.text("file_path"),
            let fileFormat = row.text("file_format"),
            let createdAtRaw = row.double("created_at")
        else {
            return nil
        }

        return ArtifactRecord(
            id: id,
            ownerType: ownerType,
            ownerID: ownerID,
            relatedTaskID: row.text("related_task_id").flatMap(UUID.init(uuidString:)),
            relatedHistoryID: row.text("related_history_id").flatMap(UUID.init(uuidString:)),
            artifactType: artifactType,
            filePath: filePath,
            fileFormat: fileFormat,
            sizeBytes: row.integer("size_bytes"),
            backend: row.text("backend"),
            provider: row.text("provider").flatMap(ProviderType.init(rawValue:)),
            model: row.text("model"),
            createdAt: Date(timeIntervalSince1970: createdAtRaw)
        )
    }
}
