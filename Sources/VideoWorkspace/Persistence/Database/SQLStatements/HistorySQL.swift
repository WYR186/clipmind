import Foundation

enum HistorySQL {
    static let upsert = """
    INSERT INTO history_entries (
        id,
        related_task_id,
        history_type,
        title,
        source_type,
        source_value,
        source_reference,
        transcript_id,
        summary_id,
        download_result_json,
        preview_text,
        backend,
        provider,
        model,
        created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        related_task_id = excluded.related_task_id,
        history_type = excluded.history_type,
        title = excluded.title,
        source_type = excluded.source_type,
        source_value = excluded.source_value,
        source_reference = excluded.source_reference,
        transcript_id = excluded.transcript_id,
        summary_id = excluded.summary_id,
        download_result_json = excluded.download_result_json,
        preview_text = excluded.preview_text,
        backend = excluded.backend,
        provider = excluded.provider,
        model = excluded.model,
        created_at = excluded.created_at;
    """

    static let selectAll = """
    SELECT
        id,
        related_task_id,
        history_type,
        source_type,
        source_value,
        transcript_id,
        summary_id,
        download_result_json,
        created_at
    FROM history_entries
    ORDER BY created_at DESC;
    """
}
