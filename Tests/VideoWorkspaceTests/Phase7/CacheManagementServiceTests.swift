import XCTest
@testable import VideoWorkspace

final class CacheManagementServiceTests: XCTestCase {
    func testClearCacheRemovesCacheAndTempFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("vw-cache-tests-\(UUID().uuidString)", isDirectory: true)
        let cacheDir = root.appendingPathComponent("cache", isDirectory: true)
        let tempRoot = root.appendingPathComponent("temp", isDirectory: true)
        let transcribeTemp = tempRoot.appendingPathComponent("videoworkspace-transcribe", isDirectory: true)

        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: transcribeTemp, withIntermediateDirectories: true)

        let cacheFile = cacheDir.appendingPathComponent("models.json")
        let tempFile = transcribeTemp.appendingPathComponent("sample.wav")
        try Data(repeating: 1, count: 1024).write(to: cacheFile)
        try Data(repeating: 2, count: 2048).write(to: tempFile)

        let logger = ConsoleLogger()
        let tempCleanup = TempFileCleanupService(tempDirectory: tempRoot, logger: logger)
        let service = CacheManagementService(
            cacheDirectory: cacheDir,
            tempCleanupService: tempCleanup,
            logger: logger
        )

        let removed = try await service.clearCache()
        XCTAssertGreaterThan(removed, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path))

        try? FileManager.default.removeItem(at: root)
    }
}
