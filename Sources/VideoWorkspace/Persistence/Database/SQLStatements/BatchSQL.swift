import Foundation

enum BatchSQL {
    static let upsertBatch = """
    INSERT INTO batch_jobs (
        id,
        title,
        source_type,
        source_descriptor,
        source_metadata_json,
        status,
        progress_fraction,
        total_count,
        completed_count,
        failed_count,
        running_count,
        pending_count,
        cancelled_count,
        operation_template_json,
        child_task_ids_json,
        last_error_summary,
        created_at,
        updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        source_type = excluded.source_type,
        source_descriptor = excluded.source_descriptor,
        source_metadata_json = excluded.source_metadata_json,
        status = excluded.status,
        progress_fraction = excluded.progress_fraction,
        total_count = excluded.total_count,
        completed_count = excluded.completed_count,
        failed_count = excluded.failed_count,
        running_count = excluded.running_count,
        pending_count = excluded.pending_count,
        cancelled_count = excluded.cancelled_count,
        operation_template_json = excluded.operation_template_json,
        child_task_ids_json = excluded.child_task_ids_json,
        last_error_summary = excluded.last_error_summary,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at;
    """

    static let upsertItem = """
    INSERT INTO batch_job_items (
        id,
        batch_job_id,
        source_type,
        source_value,
        task_id,
        status,
        progress_fraction,
        created_at,
        updated_at,
        failure_reason,
        error_code
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        batch_job_id = excluded.batch_job_id,
        source_type = excluded.source_type,
        source_value = excluded.source_value,
        task_id = excluded.task_id,
        status = excluded.status,
        progress_fraction = excluded.progress_fraction,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        failure_reason = excluded.failure_reason,
        error_code = excluded.error_code;
    """

    static let selectAllBatches = """
    SELECT
        id,
        title,
        source_type,
        source_descriptor,
        source_metadata_json,
        status,
        progress_fraction,
        total_count,
        completed_count,
        failed_count,
        running_count,
        pending_count,
        cancelled_count,
        operation_template_json,
        child_task_ids_json,
        last_error_summary,
        created_at,
        updated_at
    FROM batch_jobs
    ORDER BY created_at DESC;
    """

    static let selectBatchByID = """
    SELECT
        id,
        title,
        source_type,
        source_descriptor,
        source_metadata_json,
        status,
        progress_fraction,
        total_count,
        completed_count,
        failed_count,
        running_count,
        pending_count,
        cancelled_count,
        operation_template_json,
        child_task_ids_json,
        last_error_summary,
        created_at,
        updated_at
    FROM batch_jobs
    WHERE id = ?
    LIMIT 1;
    """

    static let selectItemsByBatchID = """
    SELECT
        id,
        batch_job_id,
        source_type,
        source_value,
        task_id,
        status,
        progress_fraction,
        created_at,
        updated_at,
        failure_reason,
        error_code
    FROM batch_job_items
    WHERE batch_job_id = ?
    ORDER BY created_at ASC;
    """

    static let markRunningItemsInterrupted = """
    UPDATE batch_job_items
    SET status = 'interrupted',
        updated_at = ?
    WHERE status = 'running';
    """

    static let markRunningBatchesInterrupted = """
    UPDATE batch_jobs
    SET status = 'interrupted',
        updated_at = ?
    WHERE status = 'running';
    """
}
