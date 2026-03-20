import Foundation

public struct SupportSummary: Codable, Hashable, Sendable {
    public let generatedAt: Date
    public let buildInfo: BuildInfo
    public let runtimeMode: AppRuntimeMode
    public let preflightStatus: PreflightSeverity
    public let toolStatus: [SupportToolStatus]
    public let providerStatus: [SupportProviderStatus]
    public let recentFailureCount: Int
    public let databasePath: String?
    public let logsPath: String
    public let cachePath: String
    public let exportPath: String

    public init(
        generatedAt: Date,
        buildInfo: BuildInfo,
        runtimeMode: AppRuntimeMode,
        preflightStatus: PreflightSeverity,
        toolStatus: [SupportToolStatus],
        providerStatus: [SupportProviderStatus],
        recentFailureCount: Int,
        databasePath: String?,
        logsPath: String,
        cachePath: String,
        exportPath: String
    ) {
        self.generatedAt = generatedAt
        self.buildInfo = buildInfo
        self.runtimeMode = runtimeMode
        self.preflightStatus = preflightStatus
        self.toolStatus = toolStatus
        self.providerStatus = providerStatus
        self.recentFailureCount = recentFailureCount
        self.databasePath = databasePath
        self.logsPath = logsPath
        self.cachePath = cachePath
        self.exportPath = exportPath
    }

    public var text: String {
        let tools = toolStatus
            .map { "\($0.tool): \($0.status.rawValue)" }
            .joined(separator: ", ")
        let providers = providerStatus
            .map { "\($0.provider.rawValue)=\($0.configured ? "configured" : "unconfigured")" }
            .joined(separator: ", ")

        return """
        App: \(buildInfo.appName) \(buildInfo.version) (\(buildInfo.buildNumber))
        Runtime: \(runtimeMode.rawValue)
        Preflight: \(preflightStatus.rawValue)
        Tools: \(tools)
        Providers: \(providers)
        Recent failures: \(recentFailureCount)
        Database: \(databasePath ?? "Not available")
        Logs: \(logsPath)
        Cache: \(cachePath)
        Exports: \(exportPath)
        """
    }
}

public struct SupportToolStatus: Codable, Hashable, Sendable {
    public let tool: String
    public let status: SmokeChecklistItemStatus

    public init(tool: String, status: SmokeChecklistItemStatus) {
        self.tool = tool
        self.status = status
    }
}

public struct SupportProviderStatus: Codable, Hashable, Sendable {
    public let provider: ProviderType
    public let configured: Bool
    public let connectionStatus: ProviderConnectionStatus

    public init(
        provider: ProviderType,
        configured: Bool,
        connectionStatus: ProviderConnectionStatus
    ) {
        self.provider = provider
        self.configured = configured
        self.connectionStatus = connectionStatus
    }
}

