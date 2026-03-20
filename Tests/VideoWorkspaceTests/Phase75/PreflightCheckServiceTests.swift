import XCTest
@testable import VideoWorkspace

final class PreflightCheckServiceTests: XCTestCase {
    func testPreflightReportsMissingToolAsNeedsAttention() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("vw-preflight-tests-\(UUID().uuidString)", isDirectory: true)
        let cacheDir = tempRoot.appendingPathComponent("cache", isDirectory: true)
        let outputDir = tempRoot.appendingPathComponent("exports", isDirectory: true)

        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let settingsRepository = InMemorySettingsRepository()
        var settings = AppSettings()
        settings.defaults.exportDirectory = outputDir.path
        await settingsRepository.saveSettings(settings)

        let cacheService = CacheManagementService(
            cacheDirectory: cacheDir,
            tempCleanupService: TempFileCleanupService(tempDirectory: tempRoot, logger: ConsoleLogger()),
            logger: ConsoleLogger()
        )

        let service = PreflightCheckService(
            settingsRepository: settingsRepository,
            cacheManagementService: cacheService,
            providerRegistry: MockProviderRegistry(),
            providerCacheRepository: InMemoryProviderCacheRepository(),
            secretsStore: MockSecretsStore(),
            notificationService: StubNotificationService(status: .authorized),
            toolLocator: StubToolLocator(availableTools: ["ffmpeg", "ffprobe"]),
            logger: ConsoleLogger(),
            databasePath: nil,
            runtimeMode: .debug
        )

        let result = await service.runChecks(force: true)
        let ytDLP = try XCTUnwrap(result.issues.first(where: { $0.key == .ytDLPAvailable }))
        XCTAssertEqual(ytDLP.severity, .needsAttention)
        XCTAssertTrue(ytDLP.suggestions.contains(.installExternalTools))
    }

    func testPreflightCachesResultWhenForceIsFalse() async {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("vw-preflight-tests-\(UUID().uuidString)", isDirectory: true)
        let cacheDir = tempRoot.appendingPathComponent("cache", isDirectory: true)
        let settingsRepository = InMemorySettingsRepository()
        var settings = AppSettings()
        settings.defaults.exportDirectory = tempRoot.appendingPathComponent("exports", isDirectory: true).path
        await settingsRepository.saveSettings(settings)
        let cacheService = CacheManagementService(
            cacheDirectory: cacheDir,
            tempCleanupService: TempFileCleanupService(tempDirectory: tempRoot, logger: ConsoleLogger()),
            logger: ConsoleLogger()
        )

        let service = PreflightCheckService(
            settingsRepository: settingsRepository,
            cacheManagementService: cacheService,
            providerRegistry: MockProviderRegistry(),
            providerCacheRepository: InMemoryProviderCacheRepository(),
            secretsStore: MockSecretsStore(),
            notificationService: StubNotificationService(status: .authorized),
            toolLocator: StubToolLocator(availableTools: ["yt-dlp", "ffmpeg", "ffprobe"]),
            logger: ConsoleLogger(),
            databasePath: nil,
            runtimeMode: .debug
        )

        let first = await service.runChecks(force: true)
        let second = await service.runChecks(force: false)
        XCTAssertEqual(first.checkedAt, second.checkedAt)
    }
}

private struct StubToolLocator: ExternalToolLocating {
    let availableTools: Set<String>

    init(availableTools: Set<String>) {
        self.availableTools = availableTools
    }

    func locate(_ toolName: String) throws -> String {
        guard availableTools.contains(toolName) else {
            throw ExternalToolError.toolNotFound(tool: toolName, searchedPaths: ["/usr/local/bin/\(toolName)"])
        }
        return "/usr/local/bin/\(toolName)"
    }
}

private actor StubNotificationService: NotificationServiceProtocol {
    let status: NotificationAuthorizationState

    init(status: NotificationAuthorizationState) {
        self.status = status
    }

    func requestAuthorization() async {}

    func authorizationStatus() async -> NotificationAuthorizationState {
        status
    }

    func notify(_ message: AppNotificationMessage) async {}
}
