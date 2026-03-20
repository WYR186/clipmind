import XCTest
@testable import VideoWorkspace

final class DiagnosticsBundleServiceTests: XCTestCase {
    func testDiagnosticsBundleRedactsSecrets() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("vw-diagnostics-tests-\(UUID().uuidString)", isDirectory: true)
        let diagnosticsDirectory = tempRoot.appendingPathComponent("Diagnostics", isDirectory: true)
        let secretsStore = MockSecretsStore()
        try await secretsStore.setSecret("sk-test-super-secret", for: ProviderType.openAI.rawValue)

        let logger = MemoryLogger()
        logger.info("Sample log line")

        let preflightResult = PreflightCheckResult(
            checkedAt: Date(),
            issues: [
                PreflightIssue(
                    key: .ytDLPAvailable,
                    severity: .ready,
                    title: "yt-dlp Available",
                    message: "Tool is available."
                )
            ]
        )

        let service = DiagnosticsBundleService(
            logger: logger,
            diagnosticsDirectory: diagnosticsDirectory,
            buildInfo: BuildInfo(appName: "VideoWorkspace", version: "1.0.0", buildNumber: "100", runtimeMode: .debug),
            runtimeMode: .debug,
            providerRegistry: MockProviderRegistry(),
            providerCacheRepository: InMemoryProviderCacheRepository(),
            secretsStore: secretsStore,
            preflightCheckService: StubPreflightService(result: preflightResult)
        )

        let tasks = [
            TaskItem(
                id: UUID(),
                source: MediaSource(type: .url, value: "https://example.com"),
                taskType: .summarize,
                status: .failed,
                progress: TaskProgressFactory.step(0.5, description: "Failed"),
                outputPath: nil,
                error: TaskError(code: "TEST_FAIL", message: "failed", technicalDetails: "details")
            )
        ]

        let output = try await service.exportBundle(
            settings: AppSettings(),
            tasks: tasks,
            historyEntries: []
        )

        let snapshotURL = output.appendingPathComponent("snapshot.json", isDirectory: false)
        let snapshotData = try Data(contentsOf: snapshotURL)
        let snapshotRaw = try XCTUnwrap(String(data: snapshotData, encoding: .utf8))
        XCTAssertFalse(snapshotRaw.contains("sk-test-super-secret"))
        XCTAssertTrue(snapshotRaw.contains("\"configured\" : true"))
        XCTAssertTrue(snapshotRaw.contains("\"buildInfo\""))
    }
}

private actor StubPreflightService: PreflightCheckServiceProtocol {
    let result: PreflightCheckResult

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

private final class MemoryLogger: @unchecked Sendable, AppLoggerProtocol {
    private var entries: [String] = []

    func debug(_ message: String) {
        entries.append("[DEBUG] \(message)")
    }

    func info(_ message: String) {
        entries.append("[INFO] \(message)")
    }

    func error(_ message: String) {
        entries.append("[ERROR] \(message)")
    }

    func recentEntries(limit: Int) -> [String] {
        Array(entries.suffix(limit))
    }
}

