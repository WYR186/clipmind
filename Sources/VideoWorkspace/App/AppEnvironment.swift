import Foundation

struct AppEnvironment {
    let taskRepository: any TaskRepositoryProtocol
    let historyRepository: any HistoryRepositoryProtocol
    let settingsRepository: any SettingsRepositoryProtocol
    let secretsStore: any SecretsStoreProtocol

    let mediaInspectionService: any MediaInspectionServiceProtocol
    let mediaDownloadService: any MediaDownloadServiceProtocol
    let mediaConversionService: any MediaConversionServiceProtocol

    let transcriptionService: any TranscriptionServiceProtocol
    let summarizationService: any SummarizationServiceProtocol

    let providerRegistry: any ProviderRegistryProtocol
    let modelDiscoveryService: any ModelDiscoveryServiceProtocol

    let logger: any AppLoggerProtocol
    let notificationService: any NotificationServiceProtocol

    let allowInspectionFallbackToMock: Bool
    let allowDownloadFallbackToMock: Bool
    let allowTranscriptionFallbackToMock: Bool
    let allowSummarizationFallbackToMock: Bool

    static func mock() -> AppEnvironment {
        let logger = ConsoleLogger()

        let commandExecutor = ProcessCommandExecutor()
        let toolLocator = ExternalToolLocator()

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
            allowFallbackToMock: true,
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
            allowFallbackToMock: true,
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

        let secretsStore = MockSecretsStore()

        let llmProviders: [ProviderType: any LLMProviderProtocol] = [
            .openAI: OpenAISummarizationService(secretsStore: secretsStore),
            .anthropic: AnthropicSummarizationService(secretsStore: secretsStore),
            .gemini: GeminiSummarizationService(secretsStore: secretsStore),
            .ollama: OllamaSummarizationService(),
            .lmStudio: LMStudioSummarizationService()
        ]

        let providerRegistry = ProviderRegistry(providers: llmProviders)
        let modelDiscoveryService = ModelDiscoveryService(providerRegistry: providerRegistry)
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
            allowFallbackToMock: true,
            logger: logger
        )

        let compositeSummarization = CompositeSummarizationService(
            providerRegistry: providerRegistry,
            fallbackService: mockSummaryFallback,
            allowFallbackToMock: true,
            logger: logger
        )

        return AppEnvironment(
            taskRepository: InMemoryTaskRepository(),
            historyRepository: InMemoryHistoryRepository(),
            settingsRepository: InMemorySettingsRepository(),
            secretsStore: secretsStore,
            mediaInspectionService: compositeInspection,
            mediaDownloadService: compositeDownload,
            mediaConversionService: ffmpegConversion,
            transcriptionService: compositeTranscription,
            summarizationService: compositeSummarization,
            providerRegistry: providerRegistry,
            modelDiscoveryService: modelDiscoveryService,
            logger: logger,
            notificationService: MockNotificationService(logger: logger),
            allowInspectionFallbackToMock: true,
            allowDownloadFallbackToMock: true,
            allowTranscriptionFallbackToMock: true,
            allowSummarizationFallbackToMock: true
        )
    }
}
