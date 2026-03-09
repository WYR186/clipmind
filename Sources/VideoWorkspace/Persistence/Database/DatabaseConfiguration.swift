import Foundation

struct DatabaseConfiguration: Sendable {
    let databaseURL: URL
    let createParentDirectories: Bool
    let busyTimeoutMilliseconds: Int32
    let enableWAL: Bool

    init(
        databaseURL: URL,
        createParentDirectories: Bool = true,
        busyTimeoutMilliseconds: Int32 = 4_000,
        enableWAL: Bool = true
    ) {
        self.databaseURL = databaseURL
        self.createParentDirectories = createParentDirectories
        self.busyTimeoutMilliseconds = busyTimeoutMilliseconds
        self.enableWAL = enableWAL
    }

    static func liveDefault(fileManager: FileManager = .default) -> DatabaseConfiguration {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

        let directory = appSupport.appendingPathComponent("VideoWorkspace", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("video_workspace.sqlite3", isDirectory: false)
        return DatabaseConfiguration(databaseURL: databaseURL)
    }

    static func temporary(name: String = "video_workspace-tests") -> DatabaseConfiguration {
        let base = FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent(name, isDirectory: true)
        let file = directory.appendingPathComponent("test-\(UUID().uuidString).sqlite3", isDirectory: false)
        return DatabaseConfiguration(databaseURL: file)
    }
}
