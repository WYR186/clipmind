import Foundation

actor PreflightCheckService: PreflightCheckServiceProtocol {
    private let settingsRepository: any SettingsRepositoryProtocol
    private let cacheManagementService: any CacheManagementServiceProtocol
    private let providerRegistry: any ProviderRegistryProtocol
    private let providerCacheRepository: any ProviderCacheRepositoryProtocol
    private let secretsStore: any SecretsStoreProtocol
    private let notificationService: any NotificationServiceProtocol
    private let toolLocator: any ExternalToolLocating
    private let logger: any AppLoggerProtocol
    private let databasePath: String?
    private let runtimeMode: AppRuntimeMode
    private var cachedResult: PreflightCheckResult?

    init(
        settingsRepository: any SettingsRepositoryProtocol,
        cacheManagementService: any CacheManagementServiceProtocol,
        providerRegistry: any ProviderRegistryProtocol,
        providerCacheRepository: any ProviderCacheRepositoryProtocol,
        secretsStore: any SecretsStoreProtocol,
        notificationService: any NotificationServiceProtocol,
        toolLocator: any ExternalToolLocating = ExternalToolLocator(),
        logger: any AppLoggerProtocol,
        databasePath: String?,
        runtimeMode: AppRuntimeMode
    ) {
        self.settingsRepository = settingsRepository
        self.cacheManagementService = cacheManagementService
        self.providerRegistry = providerRegistry
        self.providerCacheRepository = providerCacheRepository
        self.secretsStore = secretsStore
        self.notificationService = notificationService
        self.toolLocator = toolLocator
        self.logger = logger
        self.databasePath = databasePath
        self.runtimeMode = runtimeMode
    }

    func latestResult() async -> PreflightCheckResult? {
        cachedResult
    }

    func runChecks(force: Bool) async -> PreflightCheckResult {
        if !force, let cachedResult {
            return cachedResult
        }

        var issues: [PreflightIssue] = []
        issues.append(checkTool(name: "yt-dlp", key: .ytDLPAvailable))
        issues.append(checkTool(name: "ffmpeg", key: .ffmpegAvailable))
        issues.append(checkTool(name: "ffprobe", key: .ffprobeAvailable))
        issues.append(await checkOutputDirectoryWritable())
        issues.append(checkWritableDirectory(url: cacheManagementService.cacheDirectoryURL(), key: .cacheDirectoryWritable, label: "Cache Directory"))
        issues.append(checkWritableDirectory(url: cacheManagementService.temporaryDirectoryURL(), key: .tempDirectoryWritable, label: "Temporary Directory"))
        issues.append(checkDatabaseHealth())
        issues.append(await checkKeychainHealth())
        issues.append(await checkNotificationPermission())
        issues.append(await checkLocalProviderStatus(.ollama, key: .ollamaAvailability, title: "Ollama Service"))
        issues.append(await checkLocalProviderStatus(.lmStudio, key: .lmStudioAvailability, title: "LM Studio Service"))
        issues.append(await checkProviderCacheReadability())
        issues.append(checkCleanupStatus())

        let result = PreflightCheckResult(checkedAt: Date(), issues: issues)
        cachedResult = result
        logger.info("Preflight completed: \(result.overallSeverity.rawValue), attention=\(result.requiresAttentionCount), optional=\(result.optionalCount)")
        return result
    }

    private func checkTool(name: String, key: PreflightCheckKey) -> PreflightIssue {
        do {
            let path = try toolLocator.locate(name)
            return PreflightIssue(
                key: key,
                severity: .ready,
                title: "\(name) Available",
                message: "Tool is available.",
                details: path
            )
        } catch let error as ExternalToolError {
            return PreflightIssue(
                key: key,
                severity: .needsAttention,
                title: "\(name) Missing",
                message: "Install \(name) before running this workflow.",
                details: error.diagnostics,
                suggestions: [.installExternalTools, .installViaHomebrew]
            )
        } catch {
            return PreflightIssue(
                key: key,
                severity: .needsAttention,
                title: "\(name) Check Failed",
                message: "Could not verify tool availability.",
                details: error.localizedDescription,
                suggestions: [.retry]
            )
        }
    }

    private func checkWritableDirectory(
        url: URL,
        key: PreflightCheckKey,
        label: String
    ) -> PreflightIssue {
        do {
            try ensureWritable(url: url)
            return PreflightIssue(
                key: key,
                severity: .ready,
                title: "\(label) Writable",
                message: "Directory is writable.",
                details: url.path
            )
        } catch {
            return PreflightIssue(
                key: key,
                severity: .needsAttention,
                title: "\(label) Not Writable",
                message: "The app cannot write to this directory.",
                details: "\(url.path)\n\(error.localizedDescription)",
                suggestions: [.chooseWritableDirectory, .checkPermissions]
            )
        }
    }

    private func checkDatabaseHealth() -> PreflightIssue {
        guard let databasePath else {
            return PreflightIssue(
                key: .databaseHealthy,
                severity: .optional,
                title: "Database Path Not Available",
                message: "Running without live database diagnostics.",
                details: "Runtime mode: \(runtimeMode.rawValue)"
            )
        }

        let url = URL(fileURLWithPath: databasePath)
        let directory = url.deletingLastPathComponent()
        let writable = FileManager.default.isWritableFile(atPath: directory.path)
        let exists = FileManager.default.fileExists(atPath: databasePath)

        if writable {
            return PreflightIssue(
                key: .databaseHealthy,
                severity: .ready,
                title: "Database Healthy",
                message: exists ? "Database is ready." : "Database directory is writable.",
                details: databasePath
            )
        }

        return PreflightIssue(
            key: .databaseHealthy,
            severity: .needsAttention,
            title: "Database Needs Attention",
            message: "Database directory is not writable.",
            details: databasePath,
            suggestions: [.checkPermissions]
        )
    }

    private func checkOutputDirectoryWritable() async -> PreflightIssue {
        let settings = await settingsRepository.loadSettings()
        let rawPath = settings.defaults.exportDirectory
        let expanded = NSString(string: rawPath).expandingTildeInPath
        return checkWritableDirectory(
            url: URL(fileURLWithPath: expanded),
            key: .outputDirectoryWritable,
            label: "Default Export Directory"
        )
    }

    private func checkKeychainHealth() async -> PreflightIssue {
        do {
            _ = try await secretsStore.hasSecret(for: "__preflight_probe__")
            return PreflightIssue(
                key: .keychainHealthy,
                severity: .ready,
                title: "Keychain Available",
                message: "Secrets storage is available."
            )
        } catch {
            return PreflightIssue(
                key: .keychainHealthy,
                severity: .needsAttention,
                title: "Keychain Unavailable",
                message: "Secrets cannot be read from Keychain.",
                details: error.localizedDescription,
                suggestions: [.checkPermissions]
            )
        }
    }

    private func checkNotificationPermission() async -> PreflightIssue {
        let status = await notificationService.authorizationStatus()
        switch status {
        case .authorized:
            return PreflightIssue(
                key: .notificationPermission,
                severity: .ready,
                title: "Notifications Enabled",
                message: "Task completion alerts are enabled."
            )
        case .denied:
            return PreflightIssue(
                key: .notificationPermission,
                severity: .optional,
                title: "Notifications Disabled",
                message: "Enable notifications to receive completion alerts.",
                suggestions: [.enableNotificationsInSystemSettings]
            )
        case .notDetermined:
            return PreflightIssue(
                key: .notificationPermission,
                severity: .optional,
                title: "Notification Permission Pending",
                message: "Grant notification permission for completion alerts.",
                suggestions: [.enableNotificationsInSystemSettings]
            )
        case .unknown:
            return PreflightIssue(
                key: .notificationPermission,
                severity: .optional,
                title: "Notification Status Unknown",
                message: "Notification authorization status could not be detected."
            )
        }
    }

    private func checkLocalProviderStatus(
        _ provider: ProviderType,
        key: PreflightCheckKey,
        title: String
    ) async -> PreflightIssue {
        let status = await providerRegistry.connectionStatus(for: provider)
        switch status {
        case .connected:
            return PreflightIssue(
                key: key,
                severity: .ready,
                title: "\(title) Online",
                message: "Local provider is reachable."
            )
        case .disconnected, .unauthorized, .unknown:
            return PreflightIssue(
                key: key,
                severity: .optional,
                title: "\(title) Offline",
                message: "Local provider is not running or unreachable.",
                details: "Status: \(status.rawValue)",
                suggestions: [.startLocalService]
            )
        }
    }

    private func checkProviderCacheReadability() async -> PreflightIssue {
        var hasAnyCache = false
        for provider in ProviderType.allCases {
            if let entry = await providerCacheRepository.cacheEntry(for: provider),
               entry.isValid,
               !entry.models.isEmpty {
                hasAnyCache = true
                break
            }
        }

        if hasAnyCache {
            return PreflightIssue(
                key: .providerCacheReadable,
                severity: .ready,
                title: "Provider Cache Available",
                message: "Model cache is readable."
            )
        }

        return PreflightIssue(
            key: .providerCacheReadable,
            severity: .optional,
            title: "Provider Cache Empty",
            message: "No model cache yet. This is expected before first model discovery."
        )
    }

    private func checkCleanupStatus() -> PreflightIssue {
        let markerURL = cacheManagementService.cacheDirectoryURL()
            .appendingPathComponent(".cleanup-status.json", isDirectory: false)
        guard let data = try? Data(contentsOf: markerURL),
              let marker = try? JSONDecoder().decode(CacheCleanupMarker.self, from: data) else {
            return PreflightIssue(
                key: .lastCleanupStatus,
                severity: .optional,
                title: "Cleanup Status Unavailable",
                message: "No cleanup history found yet."
            )
        }

        return PreflightIssue(
            key: .lastCleanupStatus,
            severity: .ready,
            title: "Cleanup Status Available",
            message: "Last cleanup removed \(marker.removedBytes) bytes.",
            details: marker.timestamp.ISO8601Format()
        )
    }

    private func ensureWritable(url: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        let probe = url.appendingPathComponent(".write-probe-\(UUID().uuidString)", isDirectory: false)
        let data = Data("probe".utf8)
        try data.write(to: probe, options: .atomic)
        try fileManager.removeItem(at: probe)
    }
}

private struct CacheCleanupMarker: Codable {
    let timestamp: Date
    let removedBytes: Int64
}

