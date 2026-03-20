import XCTest
@testable import VideoWorkspace

final class SupportSummaryServiceTests: XCTestCase {
    func testSupportSummaryIsSanitized() async throws {
        let secretsStore = MockSecretsStore()
        try await secretsStore.setSecret("sk-secret-value", for: ProviderType.openAI.rawValue)

        let settingsRepository = InMemorySettingsRepository()
        var settings = AppSettings()
        settings.defaults.exportDirectory = "/tmp/video-workspace-export"
        await settingsRepository.saveSettings(settings)

        let taskRepository = InMemoryTaskRepository()
        await taskRepository.addTask(
            TaskItem(
                source: MediaSource(type: .url, value: "https://example.com"),
                taskType: .summarize,
                status: .failed,
                progress: TaskProgressFactory.step(0.7, description: "Failed"),
                error: TaskError(code: "FAILED", message: "failed")
            )
        )

        let preflight = PreflightCheckResult(
            checkedAt: Date(),
            issues: [
                PreflightIssue(key: .ytDLPAvailable, severity: .ready, title: "yt-dlp", message: "ok"),
                PreflightIssue(key: .ffmpegAvailable, severity: .ready, title: "ffmpeg", message: "ok"),
                PreflightIssue(key: .ffprobeAvailable, severity: .ready, title: "ffprobe", message: "ok")
            ]
        )

        let service = SupportSummaryService(
            buildInfo: BuildInfo(appName: "VideoWorkspace", version: "1.0.0", buildNumber: "100", runtimeMode: .debug),
            runtimeMode: .debug,
            preflightCheckService: StaticPreflight(result: preflight),
            providerRegistry: MockProviderRegistry(),
            secretsStore: secretsStore,
            taskRepository: taskRepository,
            settingsRepository: settingsRepository,
            databasePath: "/tmp/video-workspace.sqlite3",
            logsDirectoryURL: URL(fileURLWithPath: "/tmp/vw-logs"),
            cacheDirectoryURL: URL(fileURLWithPath: "/tmp/vw-cache")
        )

        let summary = await service.generateSummary(preflightResult: nil)
        XCTAssertEqual(summary.preflightStatus, .ready)
        XCTAssertEqual(summary.recentFailureCount, 1)
        XCTAssertFalse(summary.text.contains("sk-secret-value"))
        XCTAssertTrue(summary.text.contains("configured"))
    }
}

private actor StaticPreflight: PreflightCheckServiceProtocol {
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

