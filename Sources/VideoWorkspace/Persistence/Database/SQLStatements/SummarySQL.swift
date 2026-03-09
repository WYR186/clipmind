import Foundation

enum SummarySQL {
    static let upsert = """
    INSERT INTO summaries (
        id,
        task_id,
        history_id,
        provider,
        model_id,
        template_kind,
        output_language,
        mode,
        length,
        content,
        structured_json,
        markdown,
        plain_text,
        artifacts_json,
        primary_artifact_path,
        created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        task_id = excluded.task_id,
        history_id = excluded.history_id,
        provider = excluded.provider,
        model_id = excluded.model_id,
        template_kind = excluded.template_kind,
        output_language = excluded.output_language,
        mode = excluded.mode,
        length = excluded.length,
        content = excluded.content,
        structured_json = excluded.structured_json,
        markdown = excluded.markdown,
        plain_text = excluded.plain_text,
        artifacts_json = excluded.artifacts_json,
        primary_artifact_path = excluded.primary_artifact_path,
        created_at = excluded.created_at;
    """

    static let selectByID = """
    SELECT
        id,
        task_id,
        provider,
        model_id,
        template_kind,
        output_language,
        mode,
        length,
        content,
        structured_json,
        markdown,
        plain_text,
        artifacts_json,
        created_at
    FROM summaries
    WHERE id = ?
    LIMIT 1;
    """
}
