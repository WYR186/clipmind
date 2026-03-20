import Foundation

struct CacheManagementService: CacheManagementServiceProtocol {
    let cacheDirectory: URL
    let tempCleanupService: any TempFileCleanupServiceProtocol
    let logger: any AppLoggerProtocol

    init(
        cacheDirectory: URL,
        tempCleanupService: any TempFileCleanupServiceProtocol,
        logger: any AppLoggerProtocol
    ) {
        self.cacheDirectory = cacheDirectory
        self.tempCleanupService = tempCleanupService
        self.logger = logger
    }

    func cacheDirectoryURL() -> URL {
        cacheDirectory
    }

    func temporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("videoworkspace-transcribe", isDirectory: true)
    }

    func cacheSizeBytes() async -> Int64 {
        await directorySize(at: cacheDirectory)
    }

    func clearCache() async throws -> Int64 {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let cacheItems = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
        var removed: Int64 = 0
        for item in cacheItems {
            removed += fileSize(at: item)
            try? fileManager.removeItem(at: item)
        }

        removed += await tempCleanupService.clearAllTemporaryFiles()
        writeCleanupMarker(removedBytes: removed)
        logger.info("Cache cleared: removed \(removed) bytes")
        return removed
    }

    private func directorySize(at url: URL) async -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += fileSize(at: fileURL)
        }
        return total
    }

    private func fileSize(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              let size = values.fileSize
        else {
            return 0
        }

        return Int64(size)
    }

    private func writeCleanupMarker(removedBytes: Int64) {
        let marker = CleanupStatusMarker(timestamp: Date(), removedBytes: removedBytes)
        let markerURL = cacheDirectory.appendingPathComponent(".cleanup-status.json", isDirectory: false)
        guard let data = try? JSONEncoder().encode(marker) else { return }
        try? data.write(to: markerURL, options: .atomic)
    }
}

private struct CleanupStatusMarker: Codable {
    let timestamp: Date
    let removedBytes: Int64
}
