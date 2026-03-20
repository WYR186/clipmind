import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings = AppSettings()
    @Published var providers: [ProviderType] = []
    @Published var selectedProvider: ProviderType = .openAI
    @Published var modelDescriptors: [ModelDescriptor] = []
    @Published var providerStatus: ProviderConnectionStatus = .unknown
    @Published var apiKeyInput: String = ""
    @Published var hasStoredAPIKey: Bool = false
    @Published var providerCacheAvailable: Bool = false
    @Published var cacheDirectoryPath: String = ""
    @Published var temporaryDirectoryPath: String = ""
    @Published var cacheSizeDisplay: String = "0 B"
    @Published var preflightResult: PreflightCheckResult?
    @Published var smokeChecklistResult: SmokeChecklistResult?
    @Published var supportSummary: SupportSummary?
    @Published var recentDiagnosticPreview: String = ""
    @Published var message: String = ""

    private let environment: AppEnvironment
    let buildInfo: BuildInfo

    init(environment: AppEnvironment) {
        self.environment = environment
        self.buildInfo = environment.buildInfo
        Task {
            await load()
        }
    }

    var isAdvancedMode: Bool {
        !settings.simpleModeEnabled
    }

    var databasePathDisplay: String {
        environment.databasePath ?? "Not available"
    }

    var logsDirectoryPath: String {
        environment.logsDirectoryURL.path
    }

    func load() async {
        settings = await environment.settingsRepository.loadSettings()
        providers = await environment.providerRegistry.availableProviders()
        if providers.contains(settings.defaults.summaryProvider) {
            selectedProvider = settings.defaults.summaryProvider
        } else {
            selectedProvider = providers.first ?? settings.defaults.summaryProvider
        }
        cacheDirectoryPath = environment.cacheManagementService.cacheDirectoryURL().path
        temporaryDirectoryPath = environment.cacheManagementService.temporaryDirectoryURL().path
        await refreshCacheInfo()
        await refreshProviderStatusAndModels()
        preflightResult = await environment.preflightCheckService.runChecks(force: false)
        smokeChecklistResult = await environment.smokeChecklistService.runChecklist(force: false)
        await refreshSupportSummary()
        refreshDiagnosticPreview()
    }

    func refreshProviderStatusAndModels() async {
        providerStatus = await environment.providerRegistry.connectionStatus(for: selectedProvider)
        modelDescriptors = (try? await environment.modelDiscoveryService.discoverModels(for: selectedProvider)) ?? []
        let cacheEntry = await environment.providerCacheRepository.cacheEntry(for: selectedProvider)
        providerCacheAvailable = cacheEntry?.isValid == true && !(cacheEntry?.models.isEmpty ?? true)
        do {
            hasStoredAPIKey = try await environment.secretsStore.hasSecret(for: selectedProvider.rawValue)
        } catch {
            hasStoredAPIKey = false
        }
    }

    func saveSettings() {
        Task {
            await environment.settingsRepository.saveSettings(settings)
            NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
            message = "Settings saved"
            await refreshSupportSummary()
        }
    }

    func saveAPIKey() {
        Task {
            let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                message = "API key cannot be empty"
                return
            }
            do {
                if try await environment.secretsStore.hasSecret(for: selectedProvider.rawValue) {
                    try await environment.secretsStore.updateSecret(trimmed, for: selectedProvider.rawValue)
                } else {
                    try await environment.secretsStore.setSecret(trimmed, for: selectedProvider.rawValue)
                }
                message = "API key saved"
                hasStoredAPIKey = true
                apiKeyInput = ""
                await refreshProviderStatusAndModels()
            } catch {
                message = "Failed to save API key"
            }
        }
    }

    func deleteAPIKey() {
        Task {
            do {
                try await environment.secretsStore.removeSecret(for: selectedProvider.rawValue)
                hasStoredAPIKey = false
                apiKeyInput = ""
                message = "API key deleted"
                await refreshProviderStatusAndModels()
            } catch {
                message = "Failed to delete API key"
            }
        }
    }

    func resetToDefaults() {
        settings = AppSettings()
        Task {
            await environment.settingsRepository.saveSettings(settings)
            NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
            await refreshCacheInfo()
            await refreshProviderStatusAndModels()
            message = "Settings restored to defaults"
            await refreshSupportSummary()
        }
    }

    func requestOnboarding() {
        NotificationCenter.default.post(name: .appOnboardingRequested, object: nil)
    }

    func clearCache() {
        Task {
            do {
                let removedBytes = try await environment.cacheManagementService.clearCache()
                await refreshCacheInfo()
                message = "Cleared cache (\(ByteCountFormatter.string(fromByteCount: removedBytes, countStyle: .file)))"
                runPreflight(force: true)
                runSmokeChecklist(force: true)
            } catch {
                let mapped = ErrorPresentationMapper.map(error, context: "CacheManagement")
                message = mapped.message
            }
        }
    }

    func applyRetentionPolicy() {
        Task {
            let policy = settings.retentionPolicy
            let exportDir = settings.defaults.exportDirectory
            let summary = await environment.retentionPolicyService.applyPolicy(policy, exportDirectory: exportDir)
            await refreshCacheInfo()
            if summary.removedFileCount == 0 {
                message = "Retention policy applied — no files needed removal"
            } else {
                message = "Retention policy: removed \(summary.removedFileCount) files (\(summary.formattedRemovedBytes))"
            }
        }
    }

    func runPreflight(force: Bool) {
        Task {
            let result = await environment.preflightCheckService.runChecks(force: force)
            preflightResult = result
            message = result.overallSeverity == .ready
                ? "Readiness check complete: ready"
                : "Readiness check complete: \(result.overallSeverity.displayText)"
            await refreshSupportSummary(using: result)
            refreshDiagnosticPreview()
        }
    }

    func runSmokeChecklist(force: Bool) {
        Task {
            let result = await environment.smokeChecklistService.runChecklist(force: force)
            smokeChecklistResult = result
            preflightResult = result.preflightResult
            message = result.isAcceptable
                ? "Smoke checklist complete: acceptable"
                : "Smoke checklist complete: needs attention"
            await refreshSupportSummary(using: result.preflightResult)
        }
    }

    func copySmokeChecklistSummary() {
        guard let result = smokeChecklistResult else {
            message = "Run checklist first"
            return
        }
        let summary = """
        Smoke Checklist
        Generated: \(result.generatedAt.ISO8601Format())
        Summary: \(result.summaryLine)
        Pass: \(result.passCount), Warning: \(result.warningCount), Fail: \(result.failureCount)
        """
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary, forType: .string)
        #endif
        message = AppCopy.Diagnostics.checklistSummaryCopied
    }

    func exportSmokeChecklistResult() {
        Task {
            do {
                let location = try await environment.smokeChecklistService.exportChecklistResult(smokeChecklistResult)
                message = "\(AppCopy.Diagnostics.checklistExportedPrefix) \(location.path)"
            } catch {
                let mapped = ErrorPresentationMapper.map(error, context: "SmokeChecklistExport")
                message = mapped.message
            }
        }
    }

    func exportDiagnosticsBundle() {
        Task {
            let tasks = await environment.taskRepository.allTasks()
            let history = await environment.historyRepository.allHistoryEntries()
            do {
                let location = try await environment.diagnosticsBundleService.exportBundle(
                    settings: settings,
                    tasks: tasks,
                    historyEntries: history
                )
                message = "\(AppCopy.Diagnostics.bundleExportedPrefix) \(location.path)"
            } catch {
                let mapped = ErrorPresentationMapper.map(error, context: "DiagnosticsExport")
                message = mapped.message
            }
        }
    }

    func exportDiagnostics() {
        exportDiagnosticsBundle()
    }

    func copyDiagnosticsSummary() {
        let summary = diagnosticsSummaryText()
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary, forType: .string)
        #endif
        message = AppCopy.Diagnostics.summaryCopied
    }

    func copySupportSummary() {
        Task {
            await refreshSupportSummary()
            guard let supportSummary else {
                message = "Support summary unavailable"
                return
            }
            #if canImport(AppKit)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(supportSummary.text, forType: .string)
            #endif
            message = AppCopy.Support.summaryGenerated
        }
    }

    func openDataDirectory() {
        let url: URL
        if let databasePath = environment.databasePath {
            url = URL(fileURLWithPath: databasePath).deletingLastPathComponent()
        } else {
            url = environment.logsDirectoryURL.deletingLastPathComponent()
        }
        openDirectory(url)
    }

    func openLogsDirectory() {
        openDirectory(environment.logsDirectoryURL)
    }

    func openExportDirectory() {
        let path = NSString(string: settings.defaults.exportDirectory).expandingTildeInPath
        openDirectory(URL(fileURLWithPath: path))
    }

    func isTranscriptOutputEnabled(_ kind: TranscriptOutputKind) -> Bool {
        settings.defaults.transcriptOutputFormats.contains(kind)
    }

    func setTranscriptOutput(_ kind: TranscriptOutputKind, enabled: Bool) {
        var formats = Set(settings.defaults.transcriptOutputFormats)
        if enabled {
            formats.insert(kind)
        } else {
            formats.remove(kind)
        }

        if formats.isEmpty {
            formats.insert(.txt)
        }

        settings.defaults.transcriptOutputFormats = Array(formats).sorted { $0.rawValue < $1.rawValue }
    }

    private func refreshCacheInfo() async {
        let bytes = await environment.cacheManagementService.cacheSizeBytes()
        cacheSizeDisplay = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func refreshDiagnosticPreview() {
        let lines = environment.logger.recentEntries(limit: 6)
        recentDiagnosticPreview = lines.joined(separator: "\n")
    }

    private func diagnosticsSummaryText() -> String {
        let preflightStatus = preflightResult?.overallSeverity.displayText ?? "Unknown"
        let attention = preflightResult?.requiresAttentionCount ?? 0
        let optional = preflightResult?.optionalCount ?? 0

        return """
        \(buildInfo.appName) \(buildInfo.version) (\(buildInfo.buildNumber))
        Runtime: \(buildInfo.runtimeMode.rawValue)
        Database: \(databasePathDisplay)
        Logs: \(logsDirectoryPath)
        Cache: \(cacheDirectoryPath)
        Exports: \(settings.defaults.exportDirectory)
        Preflight: \(preflightStatus), needs attention: \(attention), optional: \(optional)
        """
    }

    private func refreshSupportSummary(using preflightResult: PreflightCheckResult? = nil) async {
        supportSummary = await environment.supportSummaryService.generateSummary(preflightResult: preflightResult ?? self.preflightResult)
    }

    private func openDirectory(_ url: URL) {
        #if canImport(AppKit)
        NSWorkspace.shared.open(url)
        #else
        _ = url
        #endif
    }
}
