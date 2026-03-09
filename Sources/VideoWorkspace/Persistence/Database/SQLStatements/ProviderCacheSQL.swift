import Foundation

enum ProviderCacheSQL {
    static let upsert = """
    INSERT INTO provider_cache (
        provider,
        cached_model_payload,
        updated_at,
        validity_marker
    ) VALUES (?, ?, ?, ?)
    ON CONFLICT(provider) DO UPDATE SET
        cached_model_payload = excluded.cached_model_payload,
        updated_at = excluded.updated_at,
        validity_marker = excluded.validity_marker;
    """

    static let selectByProvider = """
    SELECT
        provider,
        cached_model_payload,
        updated_at,
        validity_marker
    FROM provider_cache
    WHERE provider = ?
    LIMIT 1;
    """

    static let invalidate = """
    UPDATE provider_cache
    SET validity_marker = 'invalid',
        updated_at = ?
    WHERE provider = ?;
    """
}
