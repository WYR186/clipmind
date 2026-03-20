import Foundation

struct AppEnvironment {
    let taskRepository: any TaskRepositoryProtocol
    let batchJobRepository: any BatchJobRepositoryProtocol
    let historyRepository: any HistoryRepositoryProtocol
    let settingsRepository: any SettingsRepositoryProtocol
    let transcriptRepository: any TranscriptRepositoryProtocol
    let summaryRepository: any SummaryRepositoryProtocol
    let translationRepository: any TranslationRepositoryProtocol
    let artifactRepository: any ArtifactRepositoryProtocol
    let providerCacheRepository: any ProviderCacheRepositoryProtocol
    let secretsStore: any SecretsStoreProtocol

    let mediaInspectionService: any MediaInspectionServiceProtocol
    let mediaDownloadService: any MediaDownloadServiceProtocol
    let mediaConversionService: any MediaConversionServiceProtocol

    let transcriptionService: any TranscriptionServiceProtocol
    let summarizationService: any SummarizationServiceProtocol
    let translationService: any TranslationServiceProtocol

    let providerRegistry: any ProviderRegistryProtocol
    let modelDiscoveryService: any ModelDiscoveryServiceProtocol
    let artifactIndexingService: any ArtifactIndexingServiceProtocol
    let cacheManagementService: any CacheManagementServiceProtocol
    let tempFileCleanupService: any TempFileCleanupServiceProtocol
    let retentionPolicyService: any ArtifactRetentionPolicyServiceProtocol
    let diagnosticsExportService: any DiagnosticsExportServiceProtocol
    let preflightCheckService: any PreflightCheckServiceProtocol
    let diagnosticsBundleService: any DiagnosticsBundleServiceProtocol
    let smokeChecklistService: any SmokeChecklistServiceProtocol
    let supportSummaryService: any SupportSummaryServiceProtocol
    let sourceExpansionService: any SourceExpansionServiceProtocol
    let expandedSourceMapper: any ExpandedSourceMappingServiceProtocol
    let batchCreationService: any BatchCreationServiceProtocol
    let batchExecutionService: any BatchExecutionServiceProtocol

    let logger: any AppLoggerProtocol
    let notificationService: any NotificationServiceProtocol

    let runtimeMode: AppRuntimeMode
    let buildInfo: BuildInfo
    let databasePath: String?
    let logsDirectoryURL: URL
    let cacheDirectoryURL: URL
    let diagnosticsDirectoryURL: URL

    let allowInspectionFallbackToMock: Bool
    let allowDownloadFallbackToMock: Bool
    let allowTranscriptionFallbackToMock: Bool
    let allowSummarizationFallbackToMock: Bool

    static func defaultEnvironment() -> AppEnvironment {
        let runtimeMode = AppRuntimeMode.current
        let buildInfo = BuildInfo.current(runtimeMode: runtimeMode)
        do {
            return try live(runtimeMode: runtimeMode, buildInfo: buildInfo)
        } catch {
            let logger = ConsoleLogger()
            logger.error("Failed to initialize live environment: \(error.localizedDescription)")
            if runtimeMode.allowsMockFallback {
            logger.info("Falling back to mock environment in DEBUG build")
            return mock(runtimeMode: runtimeMode, buildInfo: buildInfo)
            } else {
            fatalError("Live persistence initialization failed: \(error.localizedDescription)")
            }
        }
    }

    static func live(
        runtimeMode: AppRuntimeMode = .current,
        buildInfo: BuildInfo = .current()
    ) throws -> AppEnvironment {
        let directories = resolveAppDirectories()
        let logger = FileBackedLogger(logDirectory: directories.logsDirectory)
        let databaseConfiguration = DatabaseConfiguration.liveDefault()
        let databaseManager = try DatabaseManager(
            configuration: databaseConfiguration,
            logger: logger
        )

        let taskRepository = SQLiteTaskRepository(databaseManager: databaseManager, logger: logger)
        let batchJobRepository = SQLiteBatchJobRepository(databaseManager: databaseManager, logger: logger)
        let transcriptRepository = SQLiteTranscriptRepository(databaseManager: databaseManager, logger: logger)
        let summaryRepository = SQLiteSummaryRepository(databaseManager: databaseManager, logger: logger)
        let translationRepository = SQLiteTranslationRepository(databaseManager: databaseManager, logger: logger)
        let historyRepository = SQLiteHistoryRepository(
            databaseManager: databaseManager,
            transcriptRepository: transcriptRepository,
            summaryRepository: summaryRepository,
            translationRepository: translationRepository,
            logger: logger
        )
        let settingsRepository = SQLiteSettingsRepository(databaseManager: databaseManager, logger: logger)
        let artifactRepository = SQLiteArtifactRepository(databaseManager: databaseManager, logger: logger)
        let providerCacheRepository = SQLiteProviderCacheRepository(databaseManager: databaseManager, logger: logger)

        return buildEnvironment(
            taskRepository: taskRepository,
            batchJobRepository: batchJobRepository,
            historyRepository: historyRepository,
            settingsRepository: settingsRepository,
            transcriptRepository: transcriptRepository,
            summaryRepository: summaryRepository,
            translationRepository: translationRepository,
            artifactRepository: artifactRepository,
            providerCacheRepository: providerCacheRepository,
            secretsStore: KeychainSecretsStore(),
            logger: logger,
            logsDirectory: directories.logsDirectory,
            cacheDirectory: directories.cacheDirectory,
            diagnosticsDirectory: directories.diagnosticsDirectory,
            runtimeMode: runtimeMode,
            buildInfo: buildInfo,
            databasePath: databaseConfiguration.databaseURL.path,
            useSystemNotifications: true,
            allowFallbackToMock: runtimeMode.allowsMockFallback
        )
    }

    static func mock(
        runtimeMode: AppRuntimeMode = .debug,
        buildInfo: BuildInfo? = nil
    ) -> AppEnvironment {
        let logger = ConsoleLogger()
        let resolvedBuildInfo = buildInfo ?? BuildInfo(
            appName: "VideoWorkspace",
            version: "dev",
            buildNumber: "0",
            runtimeMode: runtimeMode
        )

        let taskRepository = InMemoryTaskRepository()
        let batchJobRepository = InMemoryBatchJobRepository()
        let transcriptRepository = InMemoryTranscriptRepository()
        let summaryRepository = InMemorySummaryRepository()
        let translationRepository = InMemoryTranslationRepository()
        let historyRepository = InMemoryHistoryRepository()
        let settingsRepository = InMemorySettingsRepository()
        let artifactRepository = InMemoryArtifactRepository()
        let providerCacheRepository = InMemoryProviderCacheRepository()

        return buildEnvironment(
            taskRepository: taskRepository,
            batchJobRepository: batchJobRepository,
            historyRepository: historyRepository,
            settingsRepository: settingsRepository,
            transcriptRepository: transcriptRepository,
            summaryRepository: summaryRepository,
            translationRepository: translationRepository,
            artifactRepository: artifactRepository,
            providerCacheRepository: providerCacheRepository,
            secretsStore: MockSecretsStore(),
            logger: logger,
            logsDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("VideoWorkspaceMockLogs", isDirectory: true),
            cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("VideoWorkspaceMockCache", isDirectory: true),
            diagnosticsDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("VideoWorkspaceMockDiagnostics", isDirectory: true),
            runtimeMode: runtimeMode,
            buildInfo: resolvedBuildInfo,
            databasePath: nil,
            useSystemNotifications: false,
            allowFallbackToMock: runtimeMode.allowsMockFallback
        )
    }

    private static func buildEnvironment(
        taskRepository: any TaskRepositoryProtocol,
        batchJobRepository: any BatchJobRepositoryProtocol,
        historyRepository: any HistoryRepositoryProtocol,
        settingsRepository: any SettingsRepositoryProtocol,
        transcriptRepository: any TranscriptRepositoryProtocol,
        summaryRepository: any SummaryRepositoryProtocol,
        translationRepository: any TranslationRepositoryProtocol,
        artifactRepository: any ArtifactRepositoryProtocol,
        providerCacheRepository: any ProviderCacheRepositoryProtocol,
        secretsStore: any SecretsStoreProtocol,
        logger: any AppLoggerProtocol,
        logsDirectory: URL,
        cacheDirectory: URL,
        diagnosticsDirectory: URL,
        runtimeMode: AppRuntimeMode,
        buildInfo: BuildInfo,
        databasePath: String?,
        useSystemNotifications: Bool,
        allowFallbackToMock: Bool
    ) -> AppEnvironment {
        let commandExecutor = ProcessCommandExecutor()
        let toolLocator = ExternalToolLocator()
        let tempFileCleanupService = TempFileCleanupService(logger: logger)
        let retentionPolicyService = ArtifactRetentionPolicyService(logger: logger)
        let cacheManagementService = CacheManagementService(
            cacheDirectory: cacheDirectory,
            tempCleanupService: tempFileCleanupService,
            logger: logger
        )
        let diagnosticsExportService = DiagnosticsExportService(
            logger: logger,
            diagnosticsDirectory: diagnosticsDirectory
        )

        let mockInspection = MockMediaInspectionService()
        let ytDLPInspection = YTDLPMediaInspectionService(
            commandExecutor: commandExecutor,
            toolLocator: toolLocator,
            logger: logger
        )
        let ffprobeInspection = FFprobeMediaInspectionService(
            commandExecutor: commandExecutor,
            toolLocator: toolLocator,
            logger: logger
        )

        let compositeInspection = CompositeMediaInspectionService(
            urlInspectionService: ytDLPInspection,
            localInspectionService: ffprobeInspection,
            fallbackInspectionService: mockInspection,
            allowFallbackToMock: allowFallbackToMock,
            logger: logger
        )

        let ytDLPDownload = YTDLPMediaDownloadService(
            commandExecutor: commandExecutor,
            toolLocator: toolLocator,
            logger: logger
        )
        let compositeDownload = CompositeMediaDownloadService(
            onlineDownloadService: ytDLPDownload,
            fallbackDownloadService: MockMediaDownloadService(),
            allowFallbackToMock: allowFallbackToMock,
            logger: logger
        )

        let ffmpegConversion = FFmpegMediaConversionService(
            commandExecutor: commandExecutor,
            toolLocator: toolLocator
        )

        let preprocessingService = AudioPreprocessingService(
            commandExecutor: commandExecutor,
            toolLocator: toolLocator,
            logger: logger
        )

        let llmProviders: [ProviderType: any LLMProviderProtocol] = [
            .openAI: OpenAISummarizationService(secretsStore: secretsStore),
            .anthropic: AnthropicSummarizationService(secretsStore: secretsStore),
            .gemini: GeminiSummarizationService(secretsStore: secretsStore),
            .ollama: OllamaSummarizationService(),
            .lmStudio: LMStudioSummarizationService()
        ]

        let providerRegistry = ProviderRegistry(providers: llmProviders)
        let baseModelDiscovery = ModelDiscoveryService(providerRegistry: providerRegistry)
        let modelDiscoveryService = CachedModelDiscoveryService(
            upstream: baseModelDiscovery,
            cacheRepository: providerCacheRepository,
            logger: logger
        )
        let mockSummaryFallback = MockSummarizationService(providerRegistry: MockProviderRegistry())

        let openAITranscription = OpenAITranscriptionService(
            preprocessor: preprocessingService,
            secretsStore: secretsStore,
            logger: logger
        )
        let whisperTranscription = WhisperCPPTranscriptionService(
            preprocessor: preprocessingService,
            locator: WhisperCPPLocator(toolLocator: toolLocator),
            commandExecutor: commandExecutor,
            logger: logger
        )
        let compositeTranscription = CompositeTranscriptionService(
            openAIService: openAITranscription,
            whisperService: whisperTranscription,
            fallbackService: MockTranscriptionService(),
            allowFallbackToMock: allowFallbackToMock,
            logger: logger
        )

        let compositeSummarization = CompositeSummarizationService(
            providerRegistry: providerRegistry,
            fallbackService: mockSummaryFallback,
            allowFallbackToMock: allowFallbackToMock,
            logger: logger
        )
        let translationService = TranslationService(
            providerRegistry: providerRegistry,
            logger: logger
        )

        let artifactIndexingService = ArtifactIndexingService(
            artifactRepository: artifactRepository,
            logger: logger
        )
        let notificationService: any NotificationServiceProtocol
        if useSystemNotifications {
            if MacOSNotificationService.isSupportedInCurrentProcess() {
                notificationService = MacOSNotificationService(logger: logger)
            } else {
                notificationService = UnsupportedNotificationService(
                    logger: logger,
                    reason: "Missing app bundle identifier or non-.app runtime path (\(Bundle.main.bundleURL.path))"
                )
                logger.info("Falling back to unsupported notification service for current process runtime.")
            }
        } else {
            notificationService = MockNotificationService(logger: logger)
        }
        let preflightCheckService = PreflightCheckService(
            settingsRepository: settingsRepository,
            cacheManagementService: cacheManagementService,
            providerRegistry: providerRegistry,
            providerCacheRepository: providerCacheRepository,
            secretsStore: secretsStore,
            notificationService: notificationService,
            logger: logger,
            databasePath: databasePath,
            runtimeMode: runtimeMode
        )
        let diagnosticsBundleService = DiagnosticsBundleService(
            logger: logger,
            diagnosticsDirectory: diagnosticsDirectory,
            buildInfo: buildInfo,
            runtimeMode: runtimeMode,
            providerRegistry: providerRegistry,
            providerCacheRepository: providerCacheRepository,
            secretsStore: secretsStore,
            preflightCheckService: preflightCheckService
        )
        let smokeChecklistService = SmokeChecklistService(
            preflightCheckService: preflightCheckService,
            diagnosticsDirectory: diagnosticsDirectory,
            logger: logger
        )
        let playlistExpansionService = PlaylistExpansionService(
            commandExecutor: commandExecutor,
            toolLocator: toolLocator,
            logger: logger
        )
        let sourceExpansionService = SourceExpansionService(
            playlistExpansionService: playlistExpansionService,
            logger: logger
        )
        let expandedSourceMapper = ExpandedSourceMapper()
        let supportSummaryService = SupportSummaryService(
            buildInfo: buildInfo,
            runtimeMode: runtimeMode,
            preflightCheckService: preflightCheckService,
            providerRegistry: providerRegistry,
            secretsStore: secretsStore,
            taskRepository: taskRepository,
            settingsRepository: settingsRepository,
            databasePath: databasePath,
            logsDirectoryURL: logsDirectory,
            cacheDirectoryURL: cacheDirectory
        )
        let batchCreationService = BatchCreationService(
            batchRepository: batchJobRepository,
            logger: logger
        )
        let batchExecutionService = BatchExecutionCoordinator(
            batchRepository: batchJobRepository,
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            mediaInspectionService: compositeInspection,
            mediaDownloadService: compositeDownload,
            mediaConversionService: ffmpegConversion,
            transcriptionService: compositeTranscription,
            summarizationService: compositeSummarization,
            translationService: translationService,
            artifactIndexingService: artifactIndexingService,
            tempFileCleanupService: tempFileCleanupService,
            logger: logger,
            notificationService: notificationService
        )

        return AppEnvironment(
            taskRepository: taskRepository,
            batchJobRepository: batchJobRepository,
            historyRepository: historyRepository,
            settingsRepository: settingsRepository,
            transcriptRepository: transcriptRepository,
            summaryRepository: summaryRepository,
            translationRepository: translationRepository,
            artifactRepository: artifactRepository,
            providerCacheRepository: providerCacheRepository,
            secretsStore: secretsStore,
            mediaInspectionService: compositeInspection,
            mediaDownloadService: compositeDownload,
            mediaConversionService: ffmpegConversion,
            transcriptionService: compositeTranscription,
            summarizationService: compositeSummarization,
            translationService: translationService,
            providerRegistry: providerRegistry,
            modelDiscoveryService: modelDiscoveryService,
            artifactIndexingService: artifactIndexingService,
            cacheManagementService: cacheManagementService,
            tempFileCleanupService: tempFileCleanupService,
            retentionPolicyService: retentionPolicyService,
            diagnosticsExportService: diagnosticsExportService,
            preflightCheckService: preflightCheckService,
            diagnosticsBundleService: diagnosticsBundleService,
            smokeChecklistService: smokeChecklistService,
            supportSummaryService: supportSummaryService,
            sourceExpansionService: sourceExpansionService,
            expandedSourceMapper: expandedSourceMapper,
            batchCreationService: batchCreationService,
            batchExecutionService: batchExecutionService,
            logger: logger,
            notificationService: notificationService,
            runtimeMode: runtimeMode,
            buildInfo: buildInfo,
            databasePath: databasePath,
            logsDirectoryURL: logsDirectory,
            cacheDirectoryURL: cacheDirectory,
            diagnosticsDirectoryURL: diagnosticsDirectory,
            allowInspectionFallbackToMock: allowFallbackToMock,
            allowDownloadFallbackToMock: allowFallbackToMock,
            allowTranscriptionFallbackToMock: allowFallbackToMock,
            allowSummarizationFallbackToMock: allowFallbackToMock
        )
    }

    private static func resolveAppDirectories(fileManager: FileManager = .default) -> AppDirectories {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches", isDirectory: true)

        let base = appSupport.appendingPathComponent("VideoWorkspace", isDirectory: true)
        let logs = base.appendingPathComponent("Logs", isDirectory: true)
        let diagnostics = base.appendingPathComponent("Diagnostics", isDirectory: true)
        let cache = cacheRoot.appendingPathComponent("VideoWorkspace", isDirectory: true)
        return AppDirectories(logsDirectory: logs, cacheDirectory: cache, diagnosticsDirectory: diagnostics)
    }
}

private struct AppDirectories {
    let logsDirectory: URL
    let cacheDirectory: URL
    let diagnosticsDirectory: URL
}
