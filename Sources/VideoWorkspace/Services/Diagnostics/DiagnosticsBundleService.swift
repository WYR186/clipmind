import Foundation

struct DiagnosticsBundleService: DiagnosticsBundleServiceProtocol {
    let logger: any AppLoggerProtocol
    let diagnosticsDirectory: URL
    let buildInfo: BuildInfo
    let runtimeMode: AppRuntimeMode
    let providerRegistry: any ProviderRegistryProtocol
    let providerCacheRepository: any ProviderCacheRepositoryProtocol
    let secretsStore: any SecretsStoreProtocol
    let preflightCheckService: any PreflightCheckServiceProtocol

    init(
        logger: any AppLoggerProtocol,
        diagnosticsDirectory: URL,
        buildInfo: BuildInfo,
        runtimeMode: AppRuntimeMode,
        providerRegistry: any ProviderRegistryProtocol,
        providerCacheRepository: any ProviderCacheRepositoryProtocol,
        secretsStore: any SecretsStoreProtocol,
        preflightCheckService: any PreflightCheckServiceProtocol
    ) {
        self.logger = logger
        self.diagnosticsDirectory = diagnosticsDirectory
        self.buildInfo = buildInfo
        self.runtimeMode = runtimeMode
        self.providerRegistry = providerRegistry
        self.providerCacheRepository = providerCacheRepository
        self.secretsStore = secretsStore
        self.preflightCheckService = preflightCheckService
    }

    func exportBundle(
        settings: AppSettings,
        tasks: [TaskItem],
        historyEntries: [HistoryEntry]
    ) async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: diagnosticsDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let bundleDirectory = diagnosticsDirectory.appendingPathComponent("bundle-\(timestamp)", isDirectory: true)
        try fileManager.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

        let preflight = await preflightCheckService.runChecks(force: false)
        let providerStatuses = await collectProviderStatus()

        let snapshot = SanitizedDiagnosticsSnapshot(
            generatedAt: Date(),
            buildInfo: buildInfo,
            runtimeMode: runtimeMode,
            settings: SanitizedSettingsSnapshot(from: settings),
            preflight: preflight,
            toolSummary: buildToolSummary(from: preflight),
            providerStatus: providerStatuses,
            recentTaskFailures: buildFailureSummaries(from: tasks)
        )

        let snapshotURL = bundleDirectory.appendingPathComponent("snapshot.json", isDirectory: false)
        let snapshotData = try JSONEncoder.pretty.encode(snapshot)
        try snapshotData.write(to: snapshotURL)

        let taskSummaryURL = bundleDirectory.appendingPathComponent("task-summary.json", isDirectory: false)
        let taskSummary = [
            "taskCount": tasks.count,
            "historyCount": historyEntries.count,
            "failedTaskCount": tasks.filter { $0.status == .failed }.count
        ]
        let taskSummaryData = try JSONSerialization.data(withJSONObject: taskSummary, options: [.prettyPrinted, .sortedKeys])
        try taskSummaryData.write(to: taskSummaryURL)

        let recentLogURL = bundleDirectory.appendingPathComponent("recent.log", isDirectory: false)
        let recentLines = logger.recentEntries(limit: 600).joined(separator: "\n")
        try recentLines.data(using: .utf8)?.write(to: recentLogURL)

        if let logFile = logger.logFileURL(), fileManager.fileExists(atPath: logFile.path) {
            let destination = bundleDirectory.appendingPathComponent(logFile.lastPathComponent, isDirectory: false)
            try? fileManager.copyItem(at: logFile, to: destination)
        }

        let readmeURL = bundleDirectory.appendingPathComponent("README.txt", isDirectory: false)
        let readme = """
        VideoWorkspace Diagnostics Bundle
        Generated: \(Date().ISO8601Format())
        App: \(buildInfo.appName) \(buildInfo.version) (\(buildInfo.buildNumber))
        Runtime: \(runtimeMode.rawValue)

        Security note:
        - API keys and secrets are NOT included.
        - Provider config is exported as configured/unconfigured only.
        """
        try readme.data(using: .utf8)?.write(to: readmeURL)

        return bundleDirectory
    }

    private func collectProviderStatus() async -> [SanitizedProviderStatus] {
        let providers = await providerRegistry.availableProviders()
        var statuses: [SanitizedProviderStatus] = []
        statuses.reserveCapacity(providers.count)

        for provider in providers {
            let configured = (try? await secretsStore.hasSecret(for: provider.rawValue)) ?? false
            let connectionStatus = await providerRegistry.connectionStatus(for: provider)
            let cacheEntry = await providerCacheRepository.cacheEntry(for: provider)
            let cacheAvailable = cacheEntry?.isValid == true && !(cacheEntry?.models.isEmpty ?? true)
            statuses.append(
                SanitizedProviderStatus(
                    provider: provider,
                    configured: configured,
                    connectionStatus: connectionStatus,
                    modelCacheAvailable: cacheAvailable
                )
            )
        }

        return statuses
    }

    private func buildToolSummary(from result: PreflightCheckResult) -> [SanitizedToolStatus] {
        let targetKeys: Set<PreflightCheckKey> = [.ytDLPAvailable, .ffmpegAvailable, .ffprobeAvailable]
        return result.issues
            .filter { targetKeys.contains($0.key) }
            .map {
                SanitizedToolStatus(
                    tool: $0.key.rawValue,
                    status: $0.severity,
                    message: $0.message
                )
            }
    }

    private func buildFailureSummaries(from tasks: [TaskItem]) -> [SanitizedTaskFailure] {
        tasks
            .filter { $0.status == .failed }
            .compactMap { task in
                guard let error = task.error else { return nil }
                return SanitizedTaskFailure(
                    taskID: task.id,
                    taskType: task.taskType,
                    code: error.code,
                    message: error.message,
                    updatedAt: task.updatedAt
                )
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(20)
            .map { $0 }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

