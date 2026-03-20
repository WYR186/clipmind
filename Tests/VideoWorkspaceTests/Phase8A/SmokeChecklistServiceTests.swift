import XCTest
@testable import VideoWorkspace

final class SmokeChecklistServiceTests: XCTestCase {
    func testChecklistMapsPreflightSeverities() async {
        let preflight = PreflightCheckResult(
            checkedAt: Date(),
            issues: [
                PreflightIssue(key: .ytDLPAvailable, severity: .ready, title: "yt-dlp", message: "ok"),
                PreflightIssue(key: .notificationPermission, severity: .optional, title: "notifications", message: "optional"),
                PreflightIssue(key: .databaseHealthy, severity: .needsAttention, title: "database", message: "fail")
            ]
        )

        let service = SmokeChecklistService(
            preflightCheckService: StaticPreflightService(result: preflight),
            diagnosticsDirectory: FileManager.default.temporaryDirectory,
            logger: ConsoleLogger()
        )

        let result = await service.runChecklist(force: true)
        XCTAssertEqual(result.passCount, 1)
        XCTAssertEqual(result.warningCount, 1)
        XCTAssertEqual(result.failureCount, 1)
        XCTAssertFalse(result.isAcceptable)
    }

    func testChecklistExportWritesFiles() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vw-smoke-tests-\(UUID().uuidString)", isDirectory: true)
        let preflight = PreflightCheckResult(
            checkedAt: Date(),
            issues: [PreflightIssue(key: .ffmpegAvailable, severity: .ready, title: "ffmpeg", message: "ok")]
        )

        let service = SmokeChecklistService(
            preflightCheckService: StaticPreflightService(result: preflight),
            diagnosticsDirectory: tempDirectory,
            logger: ConsoleLogger()
        )

        let result = await service.runChecklist(force: true)
        let output = try await service.exportChecklistResult(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("smoke-checklist.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("smoke-checklist.txt").path))

        try? FileManager.default.removeItem(at: tempDirectory)
    }
}

private actor StaticPreflightService: PreflightCheckServiceProtocol {
    private let result: PreflightCheckResult

    init(result: PreflightCheckResult) {
        self.result = result
    }

    func latestResult() async -> PreflightCheckResult? {
        result
    }

    func runChecks(force: Bool) async -> PreflightCheckResult {
        _ = force
        return result
    }
}

