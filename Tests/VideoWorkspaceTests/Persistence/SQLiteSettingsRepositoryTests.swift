import XCTest
@testable import VideoWorkspace

final class SQLiteSettingsRepositoryTests: XCTestCase {
    func testSaveAndLoadSettings() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "sqlite-settings")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let logger = ConsoleLogger()
        let manager = try DatabaseManager(configuration: configuration, logger: logger)
        let repository = SQLiteSettingsRepository(databaseManager: manager, logger: logger)

        var settings = AppSettings()
        settings.themeMode = .dark
        settings.proxyMode = .custom
        settings.customProxyAddress = "http://127.0.0.1:7890"
        settings.simpleModeEnabled = false
        settings.defaults.exportDirectory = "/tmp/video-workspace"
        settings.defaults.summaryProvider = .gemini
        settings.defaults.summaryModelID = "gemini-2.0-flash"
        settings.defaults.transcriptionBackend = .openAI

        await repository.saveSettings(settings)
        let loaded = await repository.loadSettings()

        XCTAssertEqual(loaded.themeMode, .dark)
        XCTAssertEqual(loaded.proxyMode, .custom)
        XCTAssertEqual(loaded.customProxyAddress, "http://127.0.0.1:7890")
        XCTAssertEqual(loaded.simpleModeEnabled, false)
        XCTAssertEqual(loaded.defaults.exportDirectory, "/tmp/video-workspace")
        XCTAssertEqual(loaded.defaults.summaryProvider, .gemini)
        XCTAssertEqual(loaded.defaults.summaryModelID, "gemini-2.0-flash")
        XCTAssertEqual(loaded.defaults.transcriptionBackend, .openAI)
    }
}
