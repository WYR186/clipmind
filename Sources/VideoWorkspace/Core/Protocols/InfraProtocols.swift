import Foundation

public protocol AppLoggerProtocol: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func error(_ message: String)
    func logFileURL() -> URL?
    func recentEntries(limit: Int) -> [String]
}

public protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async
    func authorizationStatus() async -> NotificationAuthorizationState
    func notify(_ message: AppNotificationMessage) async
}

public enum NotificationAuthorizationState: String, Codable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unknown
}

public protocol CacheManagementServiceProtocol: Sendable {
    func cacheDirectoryURL() -> URL
    func temporaryDirectoryURL() -> URL
    func cacheSizeBytes() async -> Int64
    func clearCache() async throws -> Int64
}

public protocol TempFileCleanupServiceProtocol: Sendable {
    func cleanupAfterTaskCompletion() async
    func cleanupAfterTaskFailure() async
    func clearAllTemporaryFiles() async -> Int64
}

public protocol DiagnosticsExportServiceProtocol: Sendable {
    func exportDiagnostics(
        settings: AppSettings,
        tasks: [TaskItem],
        historyEntries: [HistoryEntry]
    ) async throws -> URL
}

public protocol PreflightCheckServiceProtocol: Sendable {
    func latestResult() async -> PreflightCheckResult?
    func runChecks(force: Bool) async -> PreflightCheckResult
}

public protocol DiagnosticsBundleServiceProtocol: Sendable {
    func exportBundle(
        settings: AppSettings,
        tasks: [TaskItem],
        historyEntries: [HistoryEntry]
    ) async throws -> URL
}

public protocol SmokeChecklistServiceProtocol: Sendable {
    func latestResult() async -> SmokeChecklistResult?
    func runChecklist(force: Bool) async -> SmokeChecklistResult
    func exportChecklistResult(_ result: SmokeChecklistResult?) async throws -> URL
}

public protocol SupportSummaryServiceProtocol: Sendable {
    func generateSummary(preflightResult: PreflightCheckResult?) async -> SupportSummary
}

public extension AppLoggerProtocol {
    func logFileURL() -> URL? {
        nil
    }

    func recentEntries(limit: Int) -> [String] {
        _ = limit
        return []
    }
}

public extension NotificationServiceProtocol {
    func authorizationStatus() async -> NotificationAuthorizationState {
        .unknown
    }
}
