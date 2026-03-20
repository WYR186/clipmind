import Foundation

struct TempFileCleanupService: TempFileCleanupServiceProtocol {
    let tempDirectory: URL
    let logger: any AppLoggerProtocol

    init(
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        logger: any AppLoggerProtocol
    ) {
        self.tempDirectory = tempDirectory
        self.logger = logger
    }

    func cleanupAfterTaskCompletion() async {
        let removed = cleanupTranscriptionTemp(olderThan: 60 * 15)
        if removed > 0 {
            logger.debug("Temp cleanup after completion removed \(removed) bytes")
        }
    }

    func cleanupAfterTaskFailure() async {
        let removed = cleanupTranscriptionTemp(olderThan: 60 * 60 * 24)
        if removed > 0 {
            logger.debug("Temp cleanup after failure removed \(removed) bytes")
        }
    }

    func clearAllTemporaryFiles() async -> Int64 {
        cleanupTranscriptionTemp(olderThan: 0)
    }

    private func cleanupTranscriptionTemp(olderThan seconds: TimeInterval) -> Int64 {
        let fileManager = FileManager.default
        let target = tempDirectory.appendingPathComponent("videoworkspace-transcribe", isDirectory: true)
        guard let items = try? fileManager.contentsOfDirectory(
            at: target,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        let threshold = Date().addingTimeInterval(-seconds)
        var removedBytes: Int64 = 0

        for item in items {
            let values = try? item.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modifiedAt = values?.contentModificationDate ?? .distantPast
            if seconds > 0, modifiedAt > threshold {
                continue
            }

            if let size = values?.fileSize {
                removedBytes += Int64(size)
            }
            try? fileManager.removeItem(at: item)
        }

        return removedBytes
    }
}
