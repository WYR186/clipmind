import Foundation

enum SettingsSQL {
    static let upsert = """
    INSERT INTO app_settings (
        key,
        value,
        value_type,
        updated_at
    ) VALUES (?, ?, ?, ?)
    ON CONFLICT(key) DO UPDATE SET
        value = excluded.value,
        value_type = excluded.value_type,
        updated_at = excluded.updated_at;
    """

    static let select = """
    SELECT value
    FROM app_settings
    WHERE key = ?
    LIMIT 1;
    """
}
