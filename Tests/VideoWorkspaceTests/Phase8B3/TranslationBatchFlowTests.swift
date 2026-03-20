import XCTest
@testable import VideoWorkspace

final class TranslationBatchFlowTests: XCTestCase {
    func testBatchTranslateCreatesHistoryWithTranslation() async throws {
        let batchRepository = InMemoryBatchJobRepository()
        let taskRepository = InMemoryTaskRepository()
        let historyRepository = InMemoryHistoryRepository()

        let coordinator = BatchExecutionCoordinator(
            batchRepository: batchRepository,
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            mediaInspectionService: BatchTranslationInspectionService(),
            mediaDownloadService: BatchTranslationDownloadService(),
            mediaConversionService: BatchTranslationConversionService(),
            transcriptionService: BatchTranslationTranscriptionService(),
            summarizationService: BatchTranslationSummarizationService(),
            translationService: BatchTranslationService(),
            artifactIndexingService: nil,
            tempFileCleanupService: nil,
            logger: ConsoleLogger(),
            notificationService: MockNotificationService(logger: ConsoleLogger())
        )

        let template = BatchOperationTemplate.fromDefaults(
            operationType: .translate,
            defaults: DefaultPreferences()
        )

        let batch = BatchJob(
            title: "Translate Batch",
            sourceType: .localFilesBatch,
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

        let item = BatchJobItem(
            batchJobID: batch.id,
            source: MediaSource(type: .localFile, value: "/tmp/input.wav")
        )

        await batchRepository.createBatch(job: batch, items: [item])
        await coordinator.start(batchJobID: batch.id)

        let finished = await waitUntil(timeout: 5) {
            guard let current = await batchRepository.batch(id: batch.id) else { return false }
            return current.status.isTerminal
        }

        XCTAssertTrue(finished)

        let items = await batchRepository.items(forBatchID: batch.id)
        XCTAssertEqual(items.first?.status, .completed)

        let history = await historyRepository.allHistoryEntries()
        XCTAssertEqual(history.count, 1)
        XCTAssertNotNil(history.first?.transcript)
        XCTAssertNotNil(history.first?.translation)
        XCTAssertEqual(history.first?.translation?.translatedText, "translated demo transcript")
    }
}

private struct BatchTranslationInspectionService: MediaInspectionServiceProtocol {
    func inspect(source: MediaSource) async throws -> MediaMetadata {
        MediaMetadata(
            source: source,
            title: "demo",
            durationSeconds: 10,
            thumbnailURL: nil,
            videoOptions: [],
            audioOptions: [],
            subtitleTracks: []
        )
    }
}

private struct BatchTranslationDownloadService: MediaDownloadServiceProtocol {
    func download(
        request: MediaDownloadRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> MediaDownloadResult {
        _ = request
        progressHandler?(TaskProgress(fractionCompleted: 1, currentStep: "Done"))
        return MediaDownloadResult(kind: .audioOnly, outputPath: "/tmp/demo.mp3", outputFileName: "demo.mp3")
    }
}

private struct BatchTranslationConversionService: MediaConversionServiceProtocol {
    func convert(request: ConversionRequest) async throws -> ConversionResult {
        ConversionResult(outputPath: request.inputPath + ".mp3")
    }
}

private struct BatchTranslationTranscriptionService: TranscriptionServiceProtocol {
    func transcribe(
        request: TranscriptionRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranscriptionResult {
        progressHandler?(TaskProgress(fractionCompleted: 1, currentStep: "Done"))
        let transcript = TranscriptItem(
            taskID: request.taskID,
            sourceType: .asr,
            languageCode: "en",
            format: .txt,
            content: "demo transcript",
            segments: [TranscriptSegment(index: 0, startSeconds: 0, endSeconds: 1, text: "demo transcript")]
        )
        return TranscriptionResult(
            transcript: transcript,
            artifacts: [TranscriptArtifact(kind: .txt, path: "/tmp/demo.txt")],
            backendUsed: .whisperCPP,
            modelUsed: "whisper",
            detectedLanguage: "en",
            durationSeconds: 1,
            diagnostics: nil
        )
    }
}

private struct BatchTranslationSummarizationService: SummarizationServiceProtocol {
    func summarize(
        request: SummarizationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> SummaryResult {
        _ = request
        progressHandler?(TaskProgress(fractionCompleted: 1, currentStep: "Done"))
        return SummaryResult(
            taskID: UUID(),
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .abstractSummary,
            length: .short,
            content: "summary"
        )
    }
}

private struct BatchTranslationService: TranslationServiceProtocol {
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
            translatedText: "translated \(request.sourceText)",
            artifacts: [TranslationArtifact(format: .txt, path: "/tmp/demo-zh.txt")]
        )
    }
}
