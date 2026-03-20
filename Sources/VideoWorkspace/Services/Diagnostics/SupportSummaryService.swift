import Foundation

struct SupportSummaryService: SupportSummaryServiceProtocol {
    let buildInfo: BuildInfo
    let runtimeMode: AppRuntimeMode
    let preflightCheckService: any PreflightCheckServiceProtocol
    let providerRegistry: any ProviderRegistryProtocol
    let secretsStore: any SecretsStoreProtocol
    let taskRepository: any TaskRepositoryProtocol
    let settingsRepository: any SettingsRepositoryProtocol
    let databasePath: String?
    let logsDirectoryURL: URL
    let cacheDirectoryURL: URL

    init(
        buildInfo: BuildInfo,
        runtimeMode: AppRuntimeMode,
        preflightCheckService: any PreflightCheckServiceProtocol,
        providerRegistry: any ProviderRegistryProtocol,
        secretsStore: any SecretsStoreProtocol,
        taskRepository: any TaskRepositoryProtocol,
        settingsRepository: any SettingsRepositoryProtocol,
        databasePath: String?,
        logsDirectoryURL: URL,
        cacheDirectoryURL: URL
    ) {
        self.buildInfo = buildInfo
        self.runtimeMode = runtimeMode
        self.preflightCheckService = preflightCheckService
        self.providerRegistry = providerRegistry
        self.secretsStore = secretsStore
        self.taskRepository = taskRepository
        self.settingsRepository = settingsRepository
        self.databasePath = databasePath
        self.logsDirectoryURL = logsDirectoryURL
        self.cacheDirectoryURL = cacheDirectoryURL
    }

    func generateSummary(preflightResult: PreflightCheckResult?) async -> SupportSummary {
        let preflight: PreflightCheckResult
        if let preflightResult {
            preflight = preflightResult
        } else {
            preflight = await preflightCheckService.runChecks(force: false)
        }
        let tasks = await taskRepository.allTasks()
        let settings = await settingsRepository.loadSettings()

        let tools = preflight.issues
            .filter { [.ytDLPAvailable, .ffmpegAvailable, .ffprobeAvailable].contains($0.key) }
            .map {
                SupportToolStatus(
                    tool: $0.key.rawValue,
                    status: mapToChecklistStatus($0.severity)
                )
            }

        let providers = await buildProviderStatuses()

        return SupportSummary(
            generatedAt: Date(),
            buildInfo: buildInfo,
            runtimeMode: runtimeMode,
            preflightStatus: preflight.overallSeverity,
            toolStatus: tools,
            providerStatus: providers,
            recentFailureCount: tasks.filter { $0.status == .failed }.count,
            databasePath: databasePath,
            logsPath: logsDirectoryURL.path,
            cachePath: cacheDirectoryURL.path,
            exportPath: settings.defaults.exportDirectory
        )
    }

    private func buildProviderStatuses() async -> [SupportProviderStatus] {
        let providers = await providerRegistry.availableProviders()
        var statuses: [SupportProviderStatus] = []
        statuses.reserveCapacity(providers.count)

        for provider in providers {
            let configured = (try? await secretsStore.hasSecret(for: provider.rawValue)) ?? false
            let status = await providerRegistry.connectionStatus(for: provider)
            statuses.append(
                SupportProviderStatus(
                    provider: provider,
                    configured: configured,
                    connectionStatus: status
                )
            )
        }

        return statuses
    }

    private func mapToChecklistStatus(_ severity: PreflightSeverity) -> SmokeChecklistItemStatus {
        switch severity {
        case .ready:
            return .pass
        case .optional:
            return .warning
        case .needsAttention:
            return .fail
        }
    }
}
