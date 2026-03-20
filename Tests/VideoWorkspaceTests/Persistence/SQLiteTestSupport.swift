import Foundation
@testable import VideoWorkspace

enum SQLiteTestSupport {
    static func makeTemporaryConfiguration(fileName: String = UUID().uuidString) -> DatabaseConfiguration {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoWorkspaceTests", isDirectory: true)
        let fileURL = directory.appendingPathComponent("\(fileName).sqlite3", isDirectory: false)
        return DatabaseConfiguration(databaseURL: fileURL)
    }

    static func cleanupDatabase(for configuration: DatabaseConfiguration) {
        let directory = configuration.databaseURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: configuration.databaseURL)
        try? FileManager.default.removeItem(at: directory)
    }
}
