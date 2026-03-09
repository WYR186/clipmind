import Foundation

enum TaskSQL {
    static let upsert = """
    INSERT INTO tasks (
        id,
        task_type,
        status,
        progress_fraction,
        progress_step,
        source_type,
        source_value,
        created_at,
        updated_at,
        output_path,
        error_code,
        error_message,
        error_technical_details
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        task_type = excluded.task_type,
        status = excluded.status,
        progress_fraction = excluded.progress_fraction,
        progress_step = excluded.progress_step,
        source_type = excluded.source_type,
        source_value = excluded.source_value,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        output_path = excluded.output_path,
        error_code = excluded.error_code,
        error_message = excluded.error_message,
        error_technical_details = excluded.error_technical_details;
    """

    static let selectAll = """
    SELECT
        id,
        task_type,
        status,
        progress_fraction,
        progress_step,
        source_type,
        source_value,
        created_at,
        updated_at,
        output_path,
        error_code,
        error_message,
        error_technical_details
    FROM tasks
    ORDER BY created_at DESC;
    """

    static let selectByID = """
    SELECT
        id,
        task_type,
        status,
        progress_fraction,
        progress_step,
        source_type,
        source_value,
        created_at,
        updated_at,
        output_path,
        error_code,
        error_message,
        error_technical_details
    FROM tasks
    WHERE id = ?
    LIMIT 1;
    """
}
