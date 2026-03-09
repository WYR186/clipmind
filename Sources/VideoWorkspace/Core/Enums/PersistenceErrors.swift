import Foundation

public enum PersistenceError: Error, Sendable {
    case databaseOpenFailed(path: String, details: String)
    case migrationFailed(version: Int, details: String)
    case unsupportedSchemaVersion(current: Int, latest: Int)
    case repositoryReadFailed(repository: String, details: String)
    case repositoryWriteFailed(repository: String, details: String)
    case settingsPersistenceFailed(details: String)
    case artifactIndexWriteFailed(details: String)
    case providerCacheWriteFailed(details: String)
}

extension PersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .databaseOpenFailed(path, _):
            return "Failed to open local database at \(path)."
        case let .migrationFailed(version, _):
            return "Database migration failed at version \(version)."
        case let .unsupportedSchemaVersion(current, latest):
            return "Database schema version \(current) is newer than supported version \(latest)."
        case let .repositoryReadFailed(repository, _):
            return "Failed to read data from \(repository)."
        case let .repositoryWriteFailed(repository, _):
            return "Failed to save data to \(repository)."
        case .settingsPersistenceFailed:
            return "Failed to save settings."
        case .artifactIndexWriteFailed:
            return "Failed to index output files."
        case .providerCacheWriteFailed:
            return "Failed to update provider cache."
        }
    }

    public var failureReason: String? {
        switch self {
        case let .databaseOpenFailed(_, details),
                let .migrationFailed(_, details),
                let .repositoryReadFailed(_, details),
                let .repositoryWriteFailed(_, details),
                let .settingsPersistenceFailed(details),
                let .artifactIndexWriteFailed(details),
                let .providerCacheWriteFailed(details):
            return details
        case .unsupportedSchemaVersion:
            return nil
        }
    }
}
