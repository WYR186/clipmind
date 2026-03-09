import Foundation
import SQLite3

struct SQLiteConnectionProvider {
    func openConnection(configuration: DatabaseConfiguration) throws -> OpaquePointer? {
        var handle: OpaquePointer?
        let path = configuration.databaseURL.path
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        let result = sqlite3_open_v2(path, &handle, flags, nil)
        guard result == SQLITE_OK, let connection = handle else {
            let details = sqliteErrorMessage(from: handle) ?? "sqlite_open_v2 failed with code \(result)"
            sqlite3_close(handle)
            throw PersistenceError.databaseOpenFailed(path: path, details: details)
        }

        sqlite3_busy_timeout(connection, configuration.busyTimeoutMilliseconds)
        if configuration.enableWAL {
            _ = sqlite3_exec(connection, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        }
        _ = sqlite3_exec(connection, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        return connection
    }

    func closeConnection(_ connection: OpaquePointer?) {
        guard let connection else { return }
        sqlite3_close(connection)
    }

    private func sqliteErrorMessage(from connection: OpaquePointer?) -> String? {
        guard let connection, let raw = sqlite3_errmsg(connection) else {
            return nil
        }
        return String(cString: raw)
    }
}
