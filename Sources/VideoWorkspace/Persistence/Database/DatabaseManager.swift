import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteBinding: Sendable {
    case integer(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
    case null
}

struct SQLiteOperation: Sendable {
    let sql: String
    let bindings: [SQLiteBinding]

    init(sql: String, bindings: [SQLiteBinding] = []) {
        self.sql = sql
        self.bindings = bindings
    }
}

struct SQLiteRow: Sendable {
    private let values: [String: SQLiteBinding]

    init(values: [String: SQLiteBinding]) {
        self.values = values
    }

    func text(_ key: String) -> String? {
        guard let value = values[key] else { return nil }
        switch value {
        case let .text(raw):
            return raw
        case let .integer(raw):
            return String(raw)
        case let .double(raw):
            return String(raw)
        case .blob, .null:
            return nil
        }
    }

    func integer(_ key: String) -> Int64? {
        guard let value = values[key] else { return nil }
        switch value {
        case let .integer(raw):
            return raw
        case let .text(raw):
            return Int64(raw)
        case let .double(raw):
            return Int64(raw)
        case .blob, .null:
            return nil
        }
    }

    func double(_ key: String) -> Double? {
        guard let value = values[key] else { return nil }
        switch value {
        case let .double(raw):
            return raw
        case let .integer(raw):
            return Double(raw)
        case let .text(raw):
            return Double(raw)
        case .blob, .null:
            return nil
        }
    }

    func blob(_ key: String) -> Data? {
        guard let value = values[key] else { return nil }
        guard case let .blob(data) = value else { return nil }
        return data
    }
}

actor DatabaseManager {
    private let configuration: DatabaseConfiguration
    private let logger: (any AppLoggerProtocol)?
    private let connectionProvider: SQLiteConnectionProvider
    private let connection: OpaquePointer?

    init(
        configuration: DatabaseConfiguration,
        logger: (any AppLoggerProtocol)? = nil,
        connectionProvider: SQLiteConnectionProvider = SQLiteConnectionProvider()
    ) throws {
        self.configuration = configuration
        self.logger = logger
        self.connectionProvider = connectionProvider

        if configuration.createParentDirectories {
            try FileManager.default.createDirectory(
                at: configuration.databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        let openedConnection = try connectionProvider.openConnection(configuration: configuration)
        do {
            try DatabaseManager.runMigrations(
                on: openedConnection,
                logger: logger
            )
        } catch {
            connectionProvider.closeConnection(openedConnection)
            throw error
        }
        self.connection = openedConnection
    }

    deinit {
        connectionProvider.closeConnection(connection)
    }

    func databasePath() -> String {
        configuration.databaseURL.path
    }

    func execute(sql: String, bindings: [SQLiteBinding] = []) throws {
        guard let connection else {
            throw PersistenceError.databaseOpenFailed(path: configuration.databaseURL.path, details: "SQLite connection is closed")
        }

        let statement = try prepareStatement(sql: sql, connection: connection)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement, connection: connection)

        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            throw makeRepositoryWriteError(details: sqliteErrorMessage(from: connection) ?? "Unknown execute failure")
        }
    }

    func query(sql: String, bindings: [SQLiteBinding] = []) throws -> [SQLiteRow] {
        guard let connection else {
            throw PersistenceError.databaseOpenFailed(path: configuration.databaseURL.path, details: "SQLite connection is closed")
        }

        let statement = try prepareStatement(sql: sql, connection: connection)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement, connection: connection)

        var rows: [SQLiteRow] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                rows.append(readRow(from: statement))
                continue
            }
            if result == SQLITE_DONE {
                break
            }
            throw makeRepositoryReadError(details: sqliteErrorMessage(from: connection) ?? "Unknown query failure")
        }

        return rows
    }

    func runTransaction(_ operations: [SQLiteOperation]) throws {
        guard !operations.isEmpty else { return }
        guard let connection else {
            throw PersistenceError.databaseOpenFailed(path: configuration.databaseURL.path, details: "SQLite connection is closed")
        }

        try execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            for operation in operations {
                try execute(sql: operation.sql, bindings: operation.bindings)
            }
            try execute(sql: "COMMIT;")
        } catch {
            _ = sqlite3_exec(connection, "ROLLBACK;", nil, nil, nil)
            throw error
        }
    }

    func schemaVersion() throws -> Int {
        Int(try readUserVersion())
    }

    private func readUserVersion() throws -> Int32 {
        let rows = try query(sql: "PRAGMA user_version;")
        return Int32(rows.first?.integer("user_version") ?? 0)
    }

    private func prepareStatement(sql: String, connection: OpaquePointer) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(connection, sql, -1, &statement, nil)
        guard result == SQLITE_OK else {
            throw makeRepositoryWriteError(details: sqliteErrorMessage(from: connection) ?? "Failed to prepare statement")
        }
        return statement
    }

    private func bind(_ bindings: [SQLiteBinding], to statement: OpaquePointer?, connection: OpaquePointer) throws {
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch binding {
            case let .integer(value):
                result = sqlite3_bind_int64(statement, index, value)
            case let .double(value):
                result = sqlite3_bind_double(statement, index, value)
            case let .text(value):
                result = sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
            case let .blob(data):
                result = data.withUnsafeBytes { rawBuffer -> Int32 in
                    guard let base = rawBuffer.baseAddress else {
                        return sqlite3_bind_blob(statement, index, nil, 0, sqliteTransient)
                    }
                    return sqlite3_bind_blob(statement, index, base, Int32(data.count), sqliteTransient)
                }
            case .null:
                result = sqlite3_bind_null(statement, index)
            }

            guard result == SQLITE_OK else {
                throw makeRepositoryWriteError(details: sqliteErrorMessage(from: connection) ?? "Failed to bind SQL value")
            }
        }
    }

    private func readRow(from statement: OpaquePointer?) -> SQLiteRow {
        let count = sqlite3_column_count(statement)
        var values: [String: SQLiteBinding] = [:]
        values.reserveCapacity(Int(count))

        for index in 0..<count {
            let name = String(cString: sqlite3_column_name(statement, index))
            let type = sqlite3_column_type(statement, index)

            let value: SQLiteBinding
            switch type {
            case SQLITE_INTEGER:
                value = .integer(sqlite3_column_int64(statement, index))
            case SQLITE_FLOAT:
                value = .double(sqlite3_column_double(statement, index))
            case SQLITE_TEXT:
                let raw = sqlite3_column_text(statement, index)
                value = .text(raw.map { String(cString: $0) } ?? "")
            case SQLITE_BLOB:
                let bytes = sqlite3_column_blob(statement, index)
                let length = Int(sqlite3_column_bytes(statement, index))
                if let bytes, length > 0 {
                    value = .blob(Data(bytes: bytes, count: length))
                } else {
                    value = .blob(Data())
                }
            default:
                value = .null
            }

            values[name] = value
        }

        return SQLiteRow(values: values)
    }

    private func sqliteErrorMessage(from connection: OpaquePointer) -> String? {
        guard let raw = sqlite3_errmsg(connection) else {
            return nil
        }
        return String(cString: raw)
    }

    private func makeRepositoryReadError(details: String) -> PersistenceError {
        PersistenceError.repositoryReadFailed(repository: "database", details: details)
    }

    private func makeRepositoryWriteError(details: String) -> PersistenceError {
        PersistenceError.repositoryWriteFailed(repository: "database", details: details)
    }
}

private extension DatabaseManager {
    static func runMigrations(on connection: OpaquePointer?, logger: (any AppLoggerProtocol)?) throws {
        let currentVersion = try readUserVersion(on: connection)
        let latestVersion = SchemaVersion.latest.rawValue

        if currentVersion > latestVersion {
            throw PersistenceError.unsupportedSchemaVersion(
                current: Int(currentVersion),
                latest: Int(latestVersion)
            )
        }

        let pending = DatabaseMigrations.all
            .filter { $0.version.rawValue > currentVersion }
            .sorted { $0.version.rawValue < $1.version.rawValue }

        guard !pending.isEmpty else { return }

        for migration in pending {
            do {
                try executeBootstrapSQL(on: connection, sql: "BEGIN IMMEDIATE TRANSACTION;")
                for statement in migration.statements {
                    try executeBootstrapSQL(on: connection, sql: statement)
                }
                try executeBootstrapSQL(
                    on: connection,
                    sql: "INSERT OR REPLACE INTO schema_migrations(version, applied_at) VALUES (?, ?);",
                    bindings: [
                        .integer(Int64(migration.version.rawValue)),
                        .double(Date().timeIntervalSince1970)
                    ]
                )
                try executeBootstrapSQL(on: connection, sql: "PRAGMA user_version = \(migration.version.rawValue);")
                try executeBootstrapSQL(on: connection, sql: "COMMIT;")
            } catch {
                if let connection {
                    _ = sqlite3_exec(connection, "ROLLBACK;", nil, nil, nil)
                }
                logger?.error("Database migration failed: v\(migration.version.rawValue) - \(error.localizedDescription)")
                throw PersistenceError.migrationFailed(
                    version: Int(migration.version.rawValue),
                    details: error.localizedDescription
                )
            }
        }
    }

    static func readUserVersion(on connection: OpaquePointer?) throws -> Int32 {
        let rows = try queryBootstrapSQL(on: connection, sql: "PRAGMA user_version;")
        return Int32(rows.first?.integer("user_version") ?? 0)
    }

    static func executeBootstrapSQL(
        on connection: OpaquePointer?,
        sql: String,
        bindings: [SQLiteBinding] = []
    ) throws {
        guard let connection else {
            throw PersistenceError.databaseOpenFailed(path: "unknown", details: "SQLite connection is closed during bootstrap")
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(connection, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            defer { sqlite3_finalize(statement) }
            let details = String(cString: sqlite3_errmsg(connection))
            throw PersistenceError.repositoryWriteFailed(repository: "database", details: details)
        }
        defer { sqlite3_finalize(statement) }

        try bindBootstrap(bindings, to: statement, connection: connection)

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE else {
            let details = String(cString: sqlite3_errmsg(connection))
            throw PersistenceError.repositoryWriteFailed(repository: "database", details: details)
        }
    }

    static func queryBootstrapSQL(
        on connection: OpaquePointer?,
        sql: String,
        bindings: [SQLiteBinding] = []
    ) throws -> [SQLiteRow] {
        guard let connection else {
            throw PersistenceError.databaseOpenFailed(path: "unknown", details: "SQLite connection is closed during bootstrap")
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(connection, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            defer { sqlite3_finalize(statement) }
            let details = String(cString: sqlite3_errmsg(connection))
            throw PersistenceError.repositoryReadFailed(repository: "database", details: details)
        }
        defer { sqlite3_finalize(statement) }

        try bindBootstrap(bindings, to: statement, connection: connection)

        var rows: [SQLiteRow] = []
        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_ROW {
                rows.append(readBootstrapRow(from: statement))
                continue
            }
            if stepResult == SQLITE_DONE {
                break
            }

            let details = String(cString: sqlite3_errmsg(connection))
            throw PersistenceError.repositoryReadFailed(repository: "database", details: details)
        }

        return rows
    }

    static func bindBootstrap(
        _ bindings: [SQLiteBinding],
        to statement: OpaquePointer?,
        connection: OpaquePointer
    ) throws {
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch binding {
            case let .integer(value):
                result = sqlite3_bind_int64(statement, index, value)
            case let .double(value):
                result = sqlite3_bind_double(statement, index, value)
            case let .text(value):
                result = sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
            case let .blob(data):
                result = data.withUnsafeBytes { rawBuffer -> Int32 in
                    guard let base = rawBuffer.baseAddress else {
                        return sqlite3_bind_blob(statement, index, nil, 0, sqliteTransient)
                    }
                    return sqlite3_bind_blob(statement, index, base, Int32(data.count), sqliteTransient)
                }
            case .null:
                result = sqlite3_bind_null(statement, index)
            }

            guard result == SQLITE_OK else {
                let details = String(cString: sqlite3_errmsg(connection))
                throw PersistenceError.repositoryWriteFailed(repository: "database", details: details)
            }
        }
    }

    static func readBootstrapRow(from statement: OpaquePointer?) -> SQLiteRow {
        let count = sqlite3_column_count(statement)
        var values: [String: SQLiteBinding] = [:]
        values.reserveCapacity(Int(count))

        for index in 0..<count {
            let name = String(cString: sqlite3_column_name(statement, index))
            let type = sqlite3_column_type(statement, index)

            let value: SQLiteBinding
            switch type {
            case SQLITE_INTEGER:
                value = .integer(sqlite3_column_int64(statement, index))
            case SQLITE_FLOAT:
                value = .double(sqlite3_column_double(statement, index))
            case SQLITE_TEXT:
                let raw = sqlite3_column_text(statement, index)
                value = .text(raw.map { String(cString: $0) } ?? "")
            case SQLITE_BLOB:
                let bytes = sqlite3_column_blob(statement, index)
                let length = Int(sqlite3_column_bytes(statement, index))
                if let bytes, length > 0 {
                    value = .blob(Data(bytes: bytes, count: length))
                } else {
                    value = .blob(Data())
                }
            default:
                value = .null
            }

            values[name] = value
        }

        return SQLiteRow(values: values)
    }
}
