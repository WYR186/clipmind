import XCTest
@testable import VideoWorkspace

final class DatabaseMigrationTests: XCTestCase {
    func testBootstrapCreatesSchemaAndVersion() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "migration-bootstrap")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let manager = try DatabaseManager(configuration: configuration, logger: ConsoleLogger())

        let version = try await manager.schemaVersion()
        XCTAssertEqual(version, Int(SchemaVersion.latest.rawValue))
        XCTAssertTrue(FileManager.default.fileExists(atPath: configuration.databaseURL.path))
    }

    func testExpectedTablesExistAfterBootstrap() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "migration-tables")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let manager = try DatabaseManager(configuration: configuration, logger: ConsoleLogger())
        let rows = try await manager.query(
            sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
        )

        let names = Set(rows.compactMap { $0.text("name") })
        XCTAssertTrue(names.contains("tasks"))
        XCTAssertTrue(names.contains("history_entries"))
        XCTAssertTrue(names.contains("transcripts"))
        XCTAssertTrue(names.contains("summaries"))
        XCTAssertTrue(names.contains("translation_results"))
        XCTAssertTrue(names.contains("artifacts"))
        XCTAssertTrue(names.contains("app_settings"))
        XCTAssertTrue(names.contains("provider_cache"))
        XCTAssertTrue(names.contains("batch_jobs"))
        XCTAssertTrue(names.contains("batch_job_items"))
    }

    func testBatchJobsIncludesSourceMetadataColumns() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "migration-batch-columns")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let manager = try DatabaseManager(configuration: configuration, logger: ConsoleLogger())
        let rows = try await manager.query(sql: "PRAGMA table_info(batch_jobs);")
        let columnNames = Set(rows.compactMap { $0.text("name") })

        XCTAssertTrue(columnNames.contains("source_descriptor"))
        XCTAssertTrue(columnNames.contains("source_metadata_json"))
    }

    func testHistoryEntriesIncludesTranslationColumn() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "migration-history-translation-column")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let manager = try DatabaseManager(configuration: configuration, logger: ConsoleLogger())
        let rows = try await manager.query(sql: "PRAGMA table_info(history_entries);")
        let columnNames = Set(rows.compactMap { $0.text("name") })

        XCTAssertTrue(columnNames.contains("translation_id"))
    }
}
