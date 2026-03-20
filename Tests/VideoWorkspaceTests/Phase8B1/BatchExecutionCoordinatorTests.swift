import XCTest
@testable import VideoWorkspace

final class BatchExecutionCoordinatorTests: XCTestCase {
    func testPartialFailureDoesNotAbortOtherItems() async throws {
        let repository = InMemoryBatchJobRepository()
        let taskRepository = InMemoryTaskRepository()
        let historyRepository = InMemoryHistoryRepository()
        let downloadService = ControlledDownloadService(
            failingSources: ["https://example.com/fail"]
        )

        let coordinator = makeCoordinator(
            batchRepository: repository,
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            downloadService: downloadService
        )

        let template = makeTemplate(operationType: .exportAudio, maxConcurrentItems: 1)

        let batch = BatchJob(
            title: "URLs",
            sourceType: .urlBatch,
            status: .queued,
            progress: BatchJobProgress(
                totalCount: 2,
                completedCount: 0,
                failedCount: 0,
                runningCount: 0,
                pendingCount: 2,
                cancelledCount: 0,
                fractionCompleted: 0
            ),
            operationTemplate: template
        )
        let items = [
            BatchJobItem(batchJobID: batch.id, source: MediaSource(type: .url, value: "https://example.com/ok")),
            BatchJobItem(batchJobID: batch.id, source: MediaSource(type: .url, value: "https://example.com/fail"))
        ]

        await repository.createBatch(job: batch, items: items)
        await coordinator.start(batchJobID: batch.id)

        let completed = await waitUntil(timeout: 5.0) {
            let items = await repository.items(forBatchID: batch.id)
            return !items.isEmpty && items.allSatisfy { $0.status.isTerminal }
        }
        XCTAssertTrue(completed)

        let finalItems = await repository.items(forBatchID: batch.id)
        XCTAssertEqual(finalItems.filter { $0.status == .completed }.count, 1)
        XCTAssertEqual(finalItems.filter { $0.status == .failed }.count, 1)
    }

    func testRetryFailedItems() async throws {
        let repository = InMemoryBatchJobRepository()
        let taskRepository = InMemoryTaskRepository()
        let historyRepository = InMemoryHistoryRepository()
        let downloadService = ControlledDownloadService(
            failingSources: ["https://example.com/retry"]
        )

        let coordinator = makeCoordinator(
            batchRepository: repository,
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            downloadService: downloadService
        )

        let template = makeTemplate(operationType: .exportAudio, maxConcurrentItems: 1)
        let batch = BatchJob(
            title: "Retry",
            sourceType: .urlBatch,
            status: .queued,
            progress: BatchJobProgress(
                totalCount: 1,
                completedCount: 0,
                failedCount: 0,
                runningCount: 0,
                pendingCount: 1,
                cancelledCount: 0,
                fractionCompleted: 0
            ),
            operationTemplate: template
        )
        let item = BatchJobItem(batchJobID: batch.id, source: MediaSource(type: .url, value: "https://example.com/retry"))
        await repository.createBatch(job: batch, items: [item])

        await coordinator.start(batchJobID: batch.id)

        _ = await waitUntil(timeout: 3.0) {
            let items = await repository.items(forBatchID: batch.id)
            if items.first?.status != .failed {
                return false
            }
            let batchState = await repository.batch(id: batch.id)
            return batchState?.status.isTerminal == true
        }

        await downloadService.clearFailingSources()
        await coordinator.retryFailedItems(batchJobID: batch.id)

        let recovered = await waitUntil(timeout: 5.0) {
            let items = await repository.items(forBatchID: batch.id)
            return items.first?.status == .completed
        }

        XCTAssertTrue(recovered)
    }

    func testCancelRemainingItemsMarksPendingAsCancelled() async throws {
        let repository = InMemoryBatchJobRepository()
        let taskRepository = InMemoryTaskRepository()
        let historyRepository = InMemoryHistoryRepository()
        let downloadService = ControlledDownloadService(
            failingSources: [],
            delayNanoseconds: 350_000_000
        )

        var template = BatchOperationTemplate.fromDefaults(
            operationType: .exportAudio,
            defaults: DefaultPreferences()
        )
        template = BatchOperationTemplate(
            operationType: template.operationType,
            outputLanguage: template.outputLanguage,
            summaryMode: template.summaryMode,
            summaryLength: template.summaryLength,
            provider: template.provider,
            modelID: template.modelID,
            summaryTemplateKind: template.summaryTemplateKind,
            outputDirectory: template.outputDirectory,
            transcriptionBackend: template.transcriptionBackend,
            openAITranscriptionModel: template.openAITranscriptionModel,
            whisperExecutablePath: template.whisperExecutablePath,
            whisperModelPath: template.whisperModelPath,
            transcriptionLanguageHint: template.transcriptionLanguageHint,
            transcriptOutputKinds: template.transcriptOutputKinds,
            overwritePolicy: template.overwritePolicy,
            resumeDownloadsEnabled: template.resumeDownloadsEnabled,
            summaryChunkingStrategy: template.summaryChunkingStrategy,
            summaryStructuredOutputPreferred: template.summaryStructuredOutputPreferred,
            summaryOutputFormat: template.summaryOutputFormat,
            maxConcurrentItems: 1
        )

        let coordinator = makeCoordinator(
            batchRepository: repository,
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            downloadService: downloadService
        )

        let batch = BatchJob(
            title: "Cancel",
            sourceType: .urlBatch,
            status: .queued,
            progress: BatchJobProgress(
                totalCount: 3,
                completedCount: 0,
                failedCount: 0,
                runningCount: 0,
                pendingCount: 3,
                cancelledCount: 0,
                fractionCompleted: 0
            ),
            operationTemplate: template
        )
        let items = [
            BatchJobItem(batchJobID: batch.id, source: MediaSource(type: .url, value: "https://example.com/1")),
            BatchJobItem(batchJobID: batch.id, source: MediaSource(type: .url, value: "https://example.com/2")),
            BatchJobItem(batchJobID: batch.id, source: MediaSource(type: .url, value: "https://example.com/3"))
        ]
        await repository.createBatch(job: batch, items: items)

        await coordinator.start(batchJobID: batch.id)
        try await Task.sleep(nanoseconds: 60_000_000)
        await coordinator.cancelRemainingItems(batchJobID: batch.id)

        let done = await waitUntil(timeout: 4.0) {
            guard let result = await repository.batch(id: batch.id) else { return false }
            return result.status.isTerminal
        }
        XCTAssertTrue(done)

        let finalItems = await repository.items(forBatchID: batch.id)
        XCTAssertTrue(finalItems.contains(where: { $0.status == .cancelled }))
    }

    private func makeCoordinator(
        batchRepository: any BatchJobRepositoryProtocol,
        taskRepository: any TaskRepositoryProtocol,
        historyRepository: any HistoryRepositoryProtocol,
        downloadService: any MediaDownloadServiceProtocol
    ) -> BatchExecutionCoordinator {
        BatchExecutionCoordinator(
            batchRepository: batchRepository,
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            mediaInspectionService: StaticInspectionService(),
            mediaDownloadService: downloadService,
            mediaConversionService: StaticConversionService(),
            transcriptionService: StaticTranscriptionService(),
            summarizationService: StaticSummarizationService(),
            translationService: StaticTranslationService(),
            artifactIndexingService: nil,
            tempFileCleanupService: nil,
            logger: ConsoleLogger(),
            notificationService: MockNotificationService(logger: ConsoleLogger())
        )
    }

    private func makeTemplate(
        operationType: BatchOperationType,
        maxConcurrentItems: Int
    ) -> BatchOperationTemplate {
        let defaults = BatchOperationTemplate.fromDefaults(
            operationType: operationType,
            defaults: DefaultPreferences()
        )
        return BatchOperationTemplate(
            operationType: defaults.operationType,
            outputLanguage: defaults.outputLanguage,
            summaryMode: defaults.summaryMode,
            summaryLength: defaults.summaryLength,
            provider: defaults.provider,
            modelID: defaults.modelID,
            summaryTemplateKind: defaults.summaryTemplateKind,
            outputDirectory: defaults.outputDirectory,
            transcriptionBackend: defaults.transcriptionBackend,
            openAITranscriptionModel: defaults.openAITranscriptionModel,
            whisperExecutablePath: defaults.whisperExecutablePath,
            whisperModelPath: defaults.whisperModelPath,
            transcriptionLanguageHint: defaults.transcriptionLanguageHint,
            transcriptOutputKinds: defaults.transcriptOutputKinds,
            overwritePolicy: defaults.overwritePolicy,
            resumeDownloadsEnabled: defaults.resumeDownloadsEnabled,
            summaryChunkingStrategy: defaults.summaryChunkingStrategy,
            summaryStructuredOutputPreferred: defaults.summaryStructuredOutputPreferred,
            summaryOutputFormat: defaults.summaryOutputFormat,
            maxConcurrentItems: maxConcurrentItems
        )
    }
}

private actor ControlledDownloadService: MediaDownloadServiceProtocol {
    private var failingSources: Set<String>
    private let delayNanoseconds: UInt64

    init(failingSources: [String], delayNanoseconds: UInt64 = 0) {
        self.failingSources = Set(failingSources)
        self.delayNanoseconds = delayNanoseconds
    }

    func clearFailingSources() {
        failingSources.removeAll()
    }

    func download(
        request: MediaDownloadRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> MediaDownloadResult {
        _ = progressHandler
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }

        if failingSources.contains(request.source.value) {
            throw DownloadError.commandExecutionFailed(
                diagnostics: ToolExecutionDiagnostics(
                    executablePath: "yt-dlp",
                    arguments: [],
                    exitCode: 1,
                    stderr: "forced failure",
                    stdoutSnippet: "",
                    durationMs: 10
                )
            )
        }
        return MediaDownloadResult(
            kind: request.kind,
            outputPath: "/tmp/\(UUID().uuidString).out",
            outputFileName: "ok.out"
        )
    }
}

private struct StaticInspectionService: MediaInspectionServiceProtocol {
    func inspect(source: MediaSource) async throws -> MediaMetadata {
        MediaMetadata(
            source: source,
            title: "demo",
            durationSeconds: 30,
            thumbnailURL: nil,
            videoOptions: [],
            audioOptions: [],
            subtitleTracks: [SubtitleTrack(languageCode: "en", languageName: "English", sourceType: .native)]
        )
    }
}

private struct StaticConversionService: MediaConversionServiceProtocol {
    func convert(request: ConversionRequest) async throws -> ConversionResult {
        ConversionResult(outputPath: request.inputPath + ".mp3")
    }
}

private struct StaticTranscriptionService: TranscriptionServiceProtocol {
    func transcribe(
        request: TranscriptionRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranscriptionResult {
        progressHandler?(TaskProgress(fractionCompleted: 1, currentStep: "Done"))
        let transcript = TranscriptItem(
            taskID: request.taskID,
            sourceType: .native,
            languageCode: request.languageHint ?? "en",
            format: .txt,
            content: "demo transcript"
        )
        return TranscriptionResult(
            transcript: transcript,
            artifacts: [],
            backendUsed: request.backend,
            modelUsed: request.modelIdentifier,
            detectedLanguage: "en",
            durationSeconds: 3,
            diagnostics: nil
        )
    }
}

private struct StaticSummarizationService: SummarizationServiceProtocol {
    func summarize(
        request: SummarizationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> SummaryResult {
        progressHandler?(TaskProgress(fractionCompleted: 1, currentStep: "Done"))
        return SummaryResult(
            taskID: request.taskID,
            provider: request.summaryRequest.provider,
            modelID: request.summaryRequest.modelID,
            mode: request.summaryRequest.mode,
            length: request.summaryRequest.length,
            content: "summary"
        )
    }
}

private struct StaticTranslationService: TranslationServiceProtocol {
    func translate(
        request: TranslationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranslationResult {
        progressHandler?(TaskProgress(fractionCompleted: 1, currentStep: "Done"))
        return TranslationResult(
            taskID: request.taskID,
            sourceTranscriptID: request.sourceTranscriptID,
            provider: request.provider,
            modelID: request.modelID,
            languagePair: request.languagePair,
            mode: request.mode,
            style: request.style,
            translatedText: "translated"
        )
    }
}
