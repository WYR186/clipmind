import Foundation

actor BatchExecutionCoordinator: BatchExecutionServiceProtocol {
    private struct OperationResult {
        let transcript: TranscriptItem?
        let summary: SummaryResult?
        let translation: TranslationResult?
        let downloadResult: MediaDownloadResult?
        let outputPath: String?
    }

    private let batchRepository: any BatchJobRepositoryProtocol
    private let taskRepository: any TaskRepositoryProtocol
    private let historyRepository: any HistoryRepositoryProtocol
    private let mediaInspectionService: any MediaInspectionServiceProtocol
    private let mediaDownloadService: any MediaDownloadServiceProtocol
    private let mediaConversionService: any MediaConversionServiceProtocol
    private let transcriptionService: any TranscriptionServiceProtocol
    private let summarizationService: any SummarizationServiceProtocol
    private let translationService: any TranslationServiceProtocol
    private let artifactIndexingService: (any ArtifactIndexingServiceProtocol)?
    private let tempFileCleanupService: (any TempFileCleanupServiceProtocol)?
    private let logger: any AppLoggerProtocol
    private let notificationService: any NotificationServiceProtocol

    private let progressAggregator = BatchProgressAggregator()
    private var activeExecutions: [BatchJobID: Task<Void, Never>] = [:]
    private var cancellationRequested: Set<BatchJobID> = []
    private var pauseRequested: Set<BatchJobID> = []
    private var restartRequested: Set<BatchJobID> = []

    init(
        batchRepository: any BatchJobRepositoryProtocol,
        taskRepository: any TaskRepositoryProtocol,
        historyRepository: any HistoryRepositoryProtocol,
        mediaInspectionService: any MediaInspectionServiceProtocol,
        mediaDownloadService: any MediaDownloadServiceProtocol,
        mediaConversionService: any MediaConversionServiceProtocol,
        transcriptionService: any TranscriptionServiceProtocol,
        summarizationService: any SummarizationServiceProtocol,
        translationService: any TranslationServiceProtocol,
        artifactIndexingService: (any ArtifactIndexingServiceProtocol)?,
        tempFileCleanupService: (any TempFileCleanupServiceProtocol)?,
        logger: any AppLoggerProtocol,
        notificationService: any NotificationServiceProtocol
    ) {
        self.batchRepository = batchRepository
        self.taskRepository = taskRepository
        self.historyRepository = historyRepository
        self.mediaInspectionService = mediaInspectionService
        self.mediaDownloadService = mediaDownloadService
        self.mediaConversionService = mediaConversionService
        self.transcriptionService = transcriptionService
        self.summarizationService = summarizationService
        self.translationService = translationService
        self.artifactIndexingService = artifactIndexingService
        self.tempFileCleanupService = tempFileCleanupService
        self.logger = logger
        self.notificationService = notificationService
    }

    func start(batchJobID: BatchJobID) async {
        guard activeExecutions[batchJobID] == nil else {
            return
        }

        let task = Task {
            await runBatch(batchJobID: batchJobID)
        }
        activeExecutions[batchJobID] = task
    }

    func pause(batchJobID: BatchJobID) async {
        guard activeExecutions[batchJobID] != nil else { return }
        pauseRequested.insert(batchJobID)
        logger.info("Pause requested for batch: \(batchJobID)")
    }

    func resume(batchJobID: BatchJobID) async {
        pauseRequested.remove(batchJobID)

        guard let batch = await batchRepository.batch(id: batchJobID),
              batch.status == .paused else {
            return
        }

        // Restart execution if not already running
        if activeExecutions[batchJobID] == nil {
            await start(batchJobID: batchJobID)
        }
        logger.info("Resume requested for batch: \(batchJobID)")
    }

    func cancelRemainingItems(batchJobID: BatchJobID) async {
        cancellationRequested.insert(batchJobID)

        let items = await batchRepository.items(forBatchID: batchJobID)
        for item in items where item.status == .pending {
            var mutable = item
            mutable.status = .cancelled
            mutable.progress = 1
            mutable.updatedAt = Date()
            mutable.failureReason = "Cancelled before execution"
            mutable.errorCode = "BATCH_ITEM_CANCELLED"
            await batchRepository.updateItem(mutable)
        }

        await refreshBatchState(batchJobID: batchJobID)
    }

    func retryFailedItems(batchJobID: BatchJobID) async {
        let items = await batchRepository.items(forBatchID: batchJobID)
        for item in items where item.status == .failed || item.status == .interrupted {
            var mutable = item
            mutable.status = .pending
            mutable.progress = 0
            mutable.updatedAt = Date()
            mutable.failureReason = nil
            mutable.errorCode = nil
            await batchRepository.updateItem(mutable)
        }

        cancellationRequested.remove(batchJobID)
        await refreshBatchState(batchJobID: batchJobID)
        if activeExecutions[batchJobID] != nil {
            restartRequested.insert(batchJobID)
            return
        }
        await start(batchJobID: batchJobID)
    }

    func executionSummary(batchJobID: BatchJobID) async -> BatchExecutionSummary? {
        guard let batch = await batchRepository.batch(id: batchJobID) else {
            return nil
        }
        let items = await batchRepository.items(forBatchID: batchJobID)
        let failed = items.filter { $0.status == .failed || $0.status == .interrupted }.map(\.id)
        let cancelled = items.filter { $0.status == .cancelled || $0.status == .skipped }.map(\.id)

        return BatchExecutionSummary(
            batchJobID: batchJobID,
            status: batch.status,
            progress: batch.progress,
            failedItemIDs: failed,
            cancelledItemIDs: cancelled,
            updatedAt: batch.updatedAt
        )
    }

    private func runBatch(batchJobID: BatchJobID) async {
        defer {
            activeExecutions[batchJobID] = nil
            cancellationRequested.remove(batchJobID)
            if restartRequested.contains(batchJobID) {
                restartRequested.remove(batchJobID)
                Task {
                    await self.start(batchJobID: batchJobID)
                }
            }
        }

        guard var batch = await batchRepository.batch(id: batchJobID) else {
            return
        }

        batch.status = .running
        batch.updatedAt = Date()
        await batchRepository.updateBatch(batch)

        while true {
            if cancellationRequested.contains(batchJobID) {
                await cancelRemainingItems(batchJobID: batchJobID)
                break
            }

            if pauseRequested.contains(batchJobID) {
                pauseRequested.remove(batchJobID)
                if var pausing = await batchRepository.batch(id: batchJobID) {
                    pausing.status = .paused
                    pausing.updatedAt = Date()
                    await batchRepository.updateBatch(pausing)
                }
                logger.info("Batch paused: \(batchJobID)")
                return // Exit the run loop; resume() will call start() again
            }

            let items = await batchRepository.items(forBatchID: batchJobID)
            let pendingItems = items.filter { $0.status == .pending }
            if pendingItems.isEmpty {
                break
            }

            let concurrency = max(1, batch.operationTemplate.maxConcurrentItems)
            let chunk = Array(pendingItems.prefix(concurrency))

            await withTaskGroup(of: Void.self) { group in
                for item in chunk {
                    group.addTask {
                        await self.executeItem(batchJobID: batchJobID, itemID: item.id)
                    }
                }
            }

            batch = await batchRepository.batch(id: batchJobID) ?? batch
            await refreshBatchState(batchJobID: batchJobID)
        }

        await refreshBatchState(batchJobID: batchJobID)

        if let summary = await executionSummary(batchJobID: batchJobID) {
            await notificationService.notify(
                AppNotificationMessage(
                    title: "Batch Finished",
                    body: "\(summary.progress.completedCount) completed, \(summary.progress.failedCount) failed"
                )
            )
        }
    }

    private func executeItem(batchJobID: BatchJobID, itemID: UUID) async {
        guard
            let batch = await batchRepository.batch(id: batchJobID),
            var item = await batchItem(batchID: batchJobID, itemID: itemID),
            item.status == .pending
        else {
            return
        }

        if cancellationRequested.contains(batchJobID) {
            item.status = .cancelled
            item.progress = 1
            item.updatedAt = Date()
            item.failureReason = "Cancelled before execution"
            item.errorCode = "BATCH_ITEM_CANCELLED"
            await batchRepository.updateItem(item)
            await refreshBatchState(batchJobID: batchJobID)
            return
        }

        let coordinator = TaskExecutionCoordinator(
            taskRepository: taskRepository,
            historyRepository: historyRepository,
            artifactIndexingService: artifactIndexingService,
            tempFileCleanupService: tempFileCleanupService,
            logger: logger,
            notificationService: notificationService
        )

        item.status = .running
        item.progress = 0.02
        item.updatedAt = Date()
        await batchRepository.updateItem(item)

        var task = TaskItem(source: item.source, taskType: batch.operationTemplate.operationType.defaultTaskType)
        await coordinator.addTask(task)
        await linkTask(task.id, toItem: item.id, in: batchJobID)

        do {
            task = await coordinator.updateTask(
                task,
                status: .running,
                progress: TaskProgressFactory.step(0.05, description: "Batch item started")
            )

            let result = try await executeOperation(
                item: item,
                task: task,
                template: batch.operationTemplate,
                batchJobID: batchJobID,
                coordinator: coordinator
            )

            let latestTask = await taskRepository.task(id: task.id) ?? task
            await coordinator.completeTask(
                latestTask,
                transcript: result.transcript,
                summary: result.summary,
                translation: result.translation,
                downloadResult: result.downloadResult,
                outputPath: result.outputPath
            )

            if var refreshed = await batchItem(batchID: batchJobID, itemID: itemID) {
                refreshed.status = .completed
                refreshed.progress = 1
                refreshed.failureReason = nil
                refreshed.errorCode = nil
                refreshed.updatedAt = Date()
                await batchRepository.updateItem(refreshed)
            }
            await refreshBatchState(batchJobID: batchJobID)
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "BatchExecution")
            await coordinator.failTask(
                task,
                error: TaskError(
                    code: mapped.code,
                    message: mapped.message,
                    technicalDetails: mapped.diagnostics
                )
            )

            if var refreshed = await batchItem(batchID: batchJobID, itemID: itemID) {
                refreshed.status = .failed
                refreshed.progress = max(refreshed.progress, 0.05)
                refreshed.failureReason = mapped.message
                refreshed.errorCode = mapped.code
                refreshed.updatedAt = Date()
                await batchRepository.updateItem(refreshed)
            }

            await setLastBatchError(batchJobID: batchJobID, summary: "\(mapped.code): \(mapped.message)")
            await refreshBatchState(batchJobID: batchJobID)
            logger.error("Batch item failed: batch=\(batchJobID) item=\(itemID) error=\(mapped.message)")
        }
    }

    private func executeOperation(
        item: BatchJobItem,
        task: TaskItem,
        template: BatchOperationTemplate,
        batchJobID: BatchJobID,
        coordinator: TaskExecutionCoordinator
    ) async throws -> OperationResult {
        switch template.operationType {
        case .exportAudio, .exportVideo, .exportSubtitle:
            return try await runExportOperation(
                item: item,
                task: task,
                template: template,
                batchJobID: batchJobID,
                coordinator: coordinator
            )
        case .copyTranscript, .transcribe, .summarize, .translate:
            return try await runTranscriptionOperation(
                item: item,
                task: task,
                template: template,
                batchJobID: batchJobID,
                coordinator: coordinator
            )
        }
    }

    private func runExportOperation(
        item: BatchJobItem,
        task: TaskItem,
        template: BatchOperationTemplate,
        batchJobID: BatchJobID,
        coordinator: TaskExecutionCoordinator
    ) async throws -> OperationResult {
        if item.source.type == .localFile {
            guard template.operationType == .exportAudio else {
                // TODO: Extend local batch export beyond audio-only conversion.
                throw DownloadError.invalidSelection(reason: "Local batch export currently supports audio-only conversion.")
            }

            await updateItemProgress(
                batchJobID: batchJobID,
                itemID: item.id,
                progress: 0.25,
                status: .running
            )
            _ = await coordinator.updateTask(
                task,
                status: .running,
                progress: TaskProgressFactory.step(0.25, description: "Converting audio")
            )

            let conversion = try await mediaConversionService.convert(
                request: ConversionRequest(inputPath: item.source.value, outputFormat: "mp3")
            )
            let outputPath = conversion.outputPath
            let outputFileName = URL(fileURLWithPath: outputPath).lastPathComponent

            let result = MediaDownloadResult(
                kind: .audioOnly,
                outputPath: outputPath,
                outputFileName: outputFileName,
                usedVideoFormatID: nil,
                usedAudioFormatID: nil,
                subtitleLanguage: nil
            )

            await updateItemProgress(
                batchJobID: batchJobID,
                itemID: item.id,
                progress: 0.9,
                status: .running
            )

            return OperationResult(
                transcript: nil,
                summary: nil,
                translation: nil,
                downloadResult: result,
                outputPath: outputPath
            )
        }

        let downloadKind = downloadKind(for: template.operationType)
        let subtitleTrack: SubtitleTrack?
        if downloadKind == .subtitle {
            let metadata = try await mediaInspectionService.inspect(source: item.source)
            subtitleTrack = metadata.subtitleTracks.first
            if subtitleTrack == nil {
                throw DownloadError.invalidSelection(reason: "Subtitle track is unavailable for this source.")
            }
        } else {
            subtitleTrack = nil
        }

        let request = MediaDownloadRequest(
            source: item.source,
            kind: downloadKind,
            metadataTitle: nil,
            selectedVideoFormatID: nil,
            selectedAudioFormatID: nil,
            selectedSubtitleTrack: subtitleTrack,
            outputDirectory: template.outputDirectory,
            preferredFileName: nil,
            resumeEnabled: template.resumeDownloadsEnabled,
            overwritePolicy: template.overwritePolicy,
            preferredSubtitleFormat: downloadKind == .subtitle ? .vtt : nil
        )

        let taskID = task.id
        let result = try await mediaDownloadService.download(
            request: request,
            progressHandler: { progress in
                Task {
                    await self.updateRunningTaskProgress(taskID: taskID, progress: progress)
                    await self.updateItemProgress(
                        batchJobID: batchJobID,
                        itemID: item.id,
                        progress: progress.fractionCompleted,
                        status: .running
                    )
                }
            }
        )

        return OperationResult(
            transcript: nil,
            summary: nil,
            translation: nil,
            downloadResult: result,
            outputPath: result.outputPath
        )
    }

    private func runTranscriptionOperation(
        item: BatchJobItem,
        task: TaskItem,
        template: BatchOperationTemplate,
        batchJobID: BatchJobID,
        coordinator: TaskExecutionCoordinator
    ) async throws -> OperationResult {
        let transcript: TranscriptItem

        if item.source.type == .url {
            await updateItemProgress(batchJobID: batchJobID, itemID: item.id, progress: 0.35, status: .running)
            _ = await coordinator.updateTask(
                task,
                status: .running,
                progress: TaskProgressFactory.step(0.35, description: "Generating transcript")
            )

            transcript = try await transcriptionService.transcribe(
                taskID: task.id,
                source: item.source,
                preferredLanguage: template.transcriptionLanguageHint ?? template.outputLanguage
            )
            await updateItemProgress(batchJobID: batchJobID, itemID: item.id, progress: 0.6, status: .running)
        } else {
            let request = TranscriptionRequest(
                taskID: task.id,
                sourcePath: item.source.value,
                sourceType: item.source.type,
                backend: template.transcriptionBackend,
                modelIdentifier: transcriptionModelIdentifier(from: template),
                outputKinds: template.transcriptOutputKinds,
                languageHint: template.transcriptionLanguageHint,
                promptHint: nil,
                temperature: nil,
                outputDirectory: template.outputDirectory,
                overwritePolicy: template.overwritePolicy,
                preprocessingRequired: true,
                debugDiagnosticsEnabled: true,
                whisperExecutablePath: template.whisperExecutablePath,
                whisperModelPath: template.whisperModelPath
            )

            let taskID = task.id
            let result = try await transcriptionService.transcribe(
                request: request,
                progressHandler: { progress in
                    Task {
                        await self.updateRunningTaskProgress(taskID: taskID, progress: progress)
                        let scaled = (template.operationType == .summarize || template.operationType == .translate)
                            ? progress.fractionCompleted * 0.55
                            : progress.fractionCompleted
                        await self.updateItemProgress(
                            batchJobID: batchJobID,
                            itemID: item.id,
                            progress: scaled,
                            status: .running
                        )
                    }
                }
            )
            transcript = result.transcript
        }

        if template.operationType != .summarize {
            if template.operationType == .translate {
                _ = await coordinator.updateTask(
                    task,
                    status: .running,
                    progress: TaskProgressFactory.step(0.65, description: "Translating transcript")
                )

                let translationRequest = TranslationRequest(
                    taskID: task.id,
                    sourceTranscriptID: transcript.id,
                    sourceText: transcript.content,
                    sourceSegments: transcript.segments,
                    sourceFormat: transcript.format,
                    languagePair: TranslationLanguagePair(
                        sourceLanguage: transcript.detectedLanguage ?? transcript.languageCode,
                        targetLanguage: template.translationTargetLanguage
                    ),
                    provider: template.provider,
                    modelID: template.modelID,
                    mode: template.translationMode,
                    style: template.translationStyle,
                    bilingualOutputEnabled: template.translationBilingualOutputEnabled,
                    preserveTimestamps: template.translationPreserveTimestamps,
                    preserveTerminology: template.translationPreserveTerminology,
                    outputFormats: template.translationOutputFormats,
                    outputDirectory: template.outputDirectory,
                    overwritePolicy: template.overwritePolicy,
                    debugDiagnosticsEnabled: true
                )

                let taskID = task.id
                let translation = try await translationService.translate(
                    request: translationRequest,
                    progressHandler: { progress in
                        Task {
                            let merged = TaskProgress(
                                fractionCompleted: 0.55 + progress.fractionCompleted * 0.45,
                                currentStep: "Translation: \(progress.currentStep)"
                            )
                            await self.updateRunningTaskProgress(taskID: taskID, progress: merged)
                            await self.updateItemProgress(
                                batchJobID: batchJobID,
                                itemID: item.id,
                                progress: 0.55 + progress.fractionCompleted * 0.45,
                                status: .running
                            )
                        }
                    }
                )

                return OperationResult(
                    transcript: transcript,
                    summary: nil,
                    translation: translation,
                    downloadResult: nil,
                    outputPath: translation.artifacts.first?.path ?? transcript.artifacts.first?.path
                )
            }

            return OperationResult(
                transcript: transcript,
                summary: nil,
                translation: nil,
                downloadResult: nil,
                outputPath: transcript.artifacts.first?.path
            )
        }

        _ = await coordinator.updateTask(
            task,
            status: .running,
            progress: TaskProgressFactory.step(0.65, description: "Generating summary")
        )

        let summaryRequest = SummaryRequest(
            provider: template.provider,
            modelID: template.modelID,
            mode: template.summaryMode,
            length: template.summaryLength,
            outputLanguage: template.outputLanguage,
            prompt: "",
            templateKind: template.summaryTemplateKind,
            customPromptOverride: nil,
            chunkingStrategy: template.summaryChunkingStrategy,
            structuredOutputPreferred: template.summaryStructuredOutputPreferred,
            outputFormat: template.summaryOutputFormat,
            debugDiagnosticsEnabled: true
        )

        let taskID = task.id
        let summary = try await summarizationService.summarize(
            request: SummarizationRequest(taskID: taskID, transcript: transcript, summaryRequest: summaryRequest),
            progressHandler: { progress in
                Task {
                    let merged = TaskProgress(
                        fractionCompleted: 0.55 + progress.fractionCompleted * 0.45,
                        currentStep: "Summary: \(progress.currentStep)"
                    )
                    await self.updateRunningTaskProgress(taskID: taskID, progress: merged)
                    await self.updateItemProgress(
                        batchJobID: batchJobID,
                        itemID: item.id,
                        progress: 0.55 + progress.fractionCompleted * 0.45,
                        status: .running
                    )
                }
            }
        )

        return OperationResult(
            transcript: transcript,
            summary: summary,
            translation: nil,
            downloadResult: nil,
            outputPath: summary.artifacts.first?.path ?? transcript.artifacts.first?.path
        )
    }

    private func linkTask(_ taskID: UUID, toItem itemID: UUID, in batchJobID: BatchJobID) async {
        if var item = await batchItem(batchID: batchJobID, itemID: itemID) {
            item.taskID = taskID
            item.updatedAt = Date()
            await batchRepository.updateItem(item)
        }

        guard var batch = await batchRepository.batch(id: batchJobID) else {
            return
        }
        if !batch.childTaskIDs.contains(taskID) {
            batch.childTaskIDs.append(taskID)
            batch.updatedAt = Date()
            await batchRepository.updateBatch(batch)
        }
    }

    private func setLastBatchError(batchJobID: BatchJobID, summary: String) async {
        guard var batch = await batchRepository.batch(id: batchJobID) else {
            return
        }
        batch.lastErrorSummary = summary
        batch.updatedAt = Date()
        await batchRepository.updateBatch(batch)
    }

    private func refreshBatchState(batchJobID: BatchJobID) async {
        guard var batch = await batchRepository.batch(id: batchJobID) else {
            return
        }

        let items = await batchRepository.items(forBatchID: batchJobID)
        let progress = progressAggregator.aggregate(items: items)
        batch.progress = progress
        batch.status = progressAggregator.status(for: items, progress: progress)
        batch.updatedAt = Date()
        await batchRepository.updateBatch(batch)
    }

    private func batchItem(batchID: BatchJobID, itemID: UUID) async -> BatchJobItem? {
        let items = await batchRepository.items(forBatchID: batchID)
        return items.first(where: { $0.id == itemID })
    }

    private func updateItemProgress(
        batchJobID: BatchJobID,
        itemID: UUID,
        progress: Double,
        status: BatchJobItemStatus
    ) async {
        guard var item = await batchItem(batchID: batchJobID, itemID: itemID) else {
            return
        }
        guard !item.status.isTerminal else {
            return
        }
        item.progress = max(item.progress, progress)
        if status != .running || item.status == .pending {
            item.status = status
        }
        item.updatedAt = Date()
        await batchRepository.updateItem(item)
    }

    private func updateRunningTaskProgress(taskID: UUID, progress: TaskProgress) async {
        guard var task = await taskRepository.task(id: taskID) else {
            return
        }
        task.status = .running
        task.progress = progress
        task.updatedAt = Date()
        await taskRepository.updateTask(task)
    }

    private func downloadKind(for operationType: BatchOperationType) -> DownloadKind {
        switch operationType {
        case .exportAudio:
            return .audioOnly
        case .exportVideo:
            return .video
        case .exportSubtitle:
            return .subtitle
        case .copyTranscript, .transcribe, .summarize, .translate:
            return .audioOnly
        }
    }

    private func transcriptionModelIdentifier(from template: BatchOperationTemplate) -> String {
        switch template.transcriptionBackend {
        case .openAI:
            return template.openAITranscriptionModel
        case .whisperCPP:
            return template.whisperModelPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (template.whisperModelPath ?? "whisper")
                : "whisper"
        }
    }
}
