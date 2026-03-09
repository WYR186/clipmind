import Foundation

struct DatabaseMigration: Sendable {
    let version: SchemaVersion
    let statements: [String]
}

enum DatabaseMigrations {
    static let all: [DatabaseMigration] = [
        DatabaseMigration(
            version: .v1,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    applied_at REAL NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS tasks (
                    id TEXT PRIMARY KEY,
                    task_type TEXT NOT NULL,
                    status TEXT NOT NULL,
                    progress_fraction REAL NOT NULL,
                    progress_step TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    source_value TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    output_path TEXT,
                    error_code TEXT,
                    error_message TEXT,
                    error_technical_details TEXT
                );
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_tasks_created_at
                ON tasks(created_at DESC);
                """,
                """
                CREATE TABLE IF NOT EXISTS transcripts (
                    id TEXT PRIMARY KEY,
                    task_id TEXT NOT NULL,
                    history_id TEXT,
                    source_type TEXT NOT NULL,
                    language_code TEXT NOT NULL,
                    format TEXT NOT NULL,
                    content TEXT NOT NULL,
                    segments_json TEXT,
                    artifacts_json TEXT,
                    backend TEXT,
                    model_id TEXT,
                    detected_language TEXT,
                    primary_artifact_path TEXT,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_transcripts_task_id
                ON transcripts(task_id);
                """,
                """
                CREATE TABLE IF NOT EXISTS summaries (
                    id TEXT PRIMARY KEY,
                    task_id TEXT NOT NULL,
                    history_id TEXT,
                    provider TEXT NOT NULL,
                    model_id TEXT NOT NULL,
                    template_kind TEXT,
                    output_language TEXT,
                    mode TEXT NOT NULL,
                    length TEXT NOT NULL,
                    content TEXT NOT NULL,
                    structured_json TEXT,
                    markdown TEXT,
                    plain_text TEXT,
                    artifacts_json TEXT,
                    primary_artifact_path TEXT,
                    created_at REAL NOT NULL
                );
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_summaries_task_id
                ON summaries(task_id);
                """,
                """
                CREATE TABLE IF NOT EXISTS history_entries (
                    id TEXT PRIMARY KEY,
                    related_task_id TEXT,
                    history_type TEXT NOT NULL,
                    title TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    source_value TEXT NOT NULL,
                    source_reference TEXT,
                    transcript_id TEXT,
                    summary_id TEXT,
                    download_result_json TEXT,
                    preview_text TEXT,
                    backend TEXT,
                    provider TEXT,
                    model TEXT,
                    created_at REAL NOT NULL,
                    FOREIGN KEY(transcript_id) REFERENCES transcripts(id) ON DELETE SET NULL,
                    FOREIGN KEY(summary_id) REFERENCES summaries(id) ON DELETE SET NULL
                );
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_history_created_at
                ON history_entries(created_at DESC);
                """,
                """
                CREATE TABLE IF NOT EXISTS artifacts (
                    id TEXT PRIMARY KEY,
                    owner_type TEXT NOT NULL,
                    owner_id TEXT NOT NULL,
                    related_task_id TEXT,
                    related_history_id TEXT,
                    artifact_type TEXT NOT NULL,
                    file_path TEXT NOT NULL,
                    file_format TEXT NOT NULL,
                    size_bytes INTEGER,
                    backend TEXT,
                    provider TEXT,
                    model TEXT,
                    created_at REAL NOT NULL
                );
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_artifacts_task
                ON artifacts(related_task_id);
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_artifacts_history
                ON artifacts(related_history_id);
                """,
                """
                CREATE INDEX IF NOT EXISTS idx_artifacts_type
                ON artifacts(artifact_type);
                """,
                """
                CREATE TABLE IF NOT EXISTS app_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    value_type TEXT NOT NULL,
                    updated_at REAL NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS provider_cache (
                    provider TEXT PRIMARY KEY,
                    cached_model_payload TEXT NOT NULL,
                    updated_at REAL NOT NULL,
                    validity_marker TEXT NOT NULL
                );
                """
            ]
        )
    ]
}
