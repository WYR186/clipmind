import Foundation

enum TranscriptSQL {
    static let upsert = """
    INSERT INTO transcripts (
        id,
        task_id,
        history_id,
        source_type,
        language_code,
        format,
        content,
        segments_json,
        artifacts_json,
        backend,
        model_id,
        detected_language,
        primary_artifact_path,
        created_at,
        updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        task_id = excluded.task_id,
        history_id = excluded.history_id,
        source_type = excluded.source_type,
        language_code = excluded.language_code,
        format = excluded.format,
        content = excluded.content,
        segments_json = excluded.segments_json,
        artifacts_json = excluded.artifacts_json,
        backend = excluded.backend,
        model_id = excluded.model_id,
        detected_language = excluded.detected_language,
        primary_artifact_path = excluded.primary_artifact_path,
        updated_at = excluded.updated_at;
    """

    static let selectByID = """
    SELECT
        id,
        task_id,
        source_type,
        language_code,
        format,
        content,
        segments_json,
        artifacts_json,
        backend,
        model_id,
        detected_language
    FROM transcripts
    WHERE id = ?
    LIMIT 1;
    """
}
