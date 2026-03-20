import Foundation

struct SanitizedDiagnosticsSnapshot: Codable, Sendable {
    let generatedAt: Date
    let buildInfo: BuildInfo
    let runtimeMode: AppRuntimeMode
    let settings: SanitizedSettingsSnapshot
    let preflight: PreflightCheckResult
    let toolSummary: [SanitizedToolStatus]
    let providerStatus: [SanitizedProviderStatus]
    let recentTaskFailures: [SanitizedTaskFailure]
}

struct SanitizedSettingsSnapshot: Codable, Sendable {
    let themeMode: ThemeMode
    let proxyMode: ProxyMode
    let customProxyConfigured: Bool
    let simpleModeEnabled: Bool
    let defaults: DefaultPreferences

    init(from settings: AppSettings) {
        self.themeMode = settings.themeMode
        self.proxyMode = settings.proxyMode
        self.customProxyConfigured = !settings.customProxyAddress
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        self.simpleModeEnabled = settings.simpleModeEnabled
        self.defaults = settings.defaults
    }
}

struct SanitizedToolStatus: Codable, Sendable {
    let tool: String
    let status: PreflightSeverity
    let message: String
}

struct SanitizedProviderStatus: Codable, Sendable {
    let provider: ProviderType
    let configured: Bool
    let connectionStatus: ProviderConnectionStatus
    let modelCacheAvailable: Bool
}

struct SanitizedTaskFailure: Codable, Sendable {
    let taskID: UUID
    let taskType: TaskType
    let code: String
    let message: String
    let updatedAt: Date
}

