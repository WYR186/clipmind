import Foundation

enum TranslationSQL {
    static let upsert = """
    INSERT INTO translation_results (
        id,
        task_id,
        history_id,
        source_transcript_id,
        provider,
        model_id,
        source_language,
        target_language,
        mode,
        style,
        translated_text,
        bilingual_text,
        segments_json,
        artifacts_json,
        diagnostics,
        primary_artifact_path,
        created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        task_id = excluded.task_id,
        history_id = excluded.history_id,
        source_transcript_id = excluded.source_transcript_id,
        provider = excluded.provider,
        model_id = excluded.model_id,
        source_language = excluded.source_language,
        target_language = excluded.target_language,
        mode = excluded.mode,
        style = excluded.style,
        translated_text = excluded.translated_text,
        bilingual_text = excluded.bilingual_text,
        segments_json = excluded.segments_json,
        artifacts_json = excluded.artifacts_json,
        diagnostics = excluded.diagnostics,
        primary_artifact_path = excluded.primary_artifact_path,
        created_at = excluded.created_at;
    """

    static let selectByID = """
    SELECT
        id,
        task_id,
        source_transcript_id,
        provider,
        model_id,
        source_language,
        target_language,
        mode,
        style,
        translated_text,
        bilingual_text,
        segments_json,
        artifacts_json,
        diagnostics,
        created_at
    FROM translation_results
    WHERE id = ?
    LIMIT 1;
    """
}
