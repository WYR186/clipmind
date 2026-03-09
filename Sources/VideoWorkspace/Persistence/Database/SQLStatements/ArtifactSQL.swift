import Foundation

enum ArtifactSQL {
    static let upsert = """
    INSERT INTO artifacts (
        id,
        owner_type,
        owner_id,
        related_task_id,
        related_history_id,
        artifact_type,
        file_path,
        file_format,
        size_bytes,
        backend,
        provider,
        model,
        created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        owner_type = excluded.owner_type,
        owner_id = excluded.owner_id,
        related_task_id = excluded.related_task_id,
        related_history_id = excluded.related_history_id,
        artifact_type = excluded.artifact_type,
        file_path = excluded.file_path,
        file_format = excluded.file_format,
        size_bytes = excluded.size_bytes,
        backend = excluded.backend,
        provider = excluded.provider,
        model = excluded.model,
        created_at = excluded.created_at;
    """

    static let selectByTaskID = """
    SELECT
        id,
        owner_type,
        owner_id,
        related_task_id,
        related_history_id,
        artifact_type,
        file_path,
        file_format,
        size_bytes,
        backend,
        provider,
        model,
        created_at
    FROM artifacts
    WHERE related_task_id = ?
    ORDER BY created_at DESC;
    """

    static let selectByHistoryID = """
    SELECT
        id,
        owner_type,
        owner_id,
        related_task_id,
        related_history_id,
        artifact_type,
        file_path,
        file_format,
        size_bytes,
        backend,
        provider,
        model,
        created_at
    FROM artifacts
    WHERE related_history_id = ?
    ORDER BY created_at DESC;
    """

    static let selectByType = """
    SELECT
        id,
        owner_type,
        owner_id,
        related_task_id,
        related_history_id,
        artifact_type,
        file_path,
        file_format,
        size_bytes,
        backend,
        provider,
        model,
        created_at
    FROM artifacts
    WHERE artifact_type = ?
    ORDER BY created_at DESC;
    """
}
