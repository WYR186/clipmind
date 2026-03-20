import Foundation

@MainActor
final class OnlineVideoViewModel: ObservableObject {
    @Published var urlInput: String = MockSamples.onlineURL
    @Published var metadata: MediaMetadata?
    @Published var selectedSubtitleTrackID: UUID?
    @Published var selectedVideoFormatID: String = ""
    @Published var selectedAudioFormatID: String = ""
    @Published var preferredSubtitleFormat: SubtitleExportFormat = .vtt
    @Published var outputDirectoryInput: String = ""
    @Published var batchURLsInput: String = ""
    @Published var batchOperationType: BatchOperationType = .exportAudio
    @Published var isCreatingBatch: Bool = false
    @Published var isExpandingPlaylist: Bool = false
    @Published var playlistMetadata: PlaylistMetadata?
    @Published var expandedPlaylistItems: [ExpandedSourceItem] = []
    @Published var playlistSkippedItems: [ExpandedSourceItem] = []

    @Published var isInspecting: Bool = false
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = ""
    @Published var lastOperationSummary: String = ""
    @Published var latestError: UserFacingError?
    @Published private(set) var isAdvancedMode: Bool = false
    @Published private(set) var canOfferTranscriptionFallback: Bool = false

    @Published var selectedProvider: ProviderType = .openAI
    @Published var availableModels: [ModelDescriptor] = []
    @Published var selectedModelID: String = ""

    @Published var resumeDownloadsEnabled: Bool = true
    @Published var overwritePolicy: FileOverwritePolicy = .renameIfNeeded

    private let environment: AppEnvironment
    private var latestTranscript: TranscriptItem?
    private var preferredVideoQuality: String = "720p"
    private var defaultSummaryLanguage: String = "en"
    private var defaultSummaryMode: SummaryMode = .abstractSummary
    private var defaultSummaryLength: SummaryLength = .medium
    private var latestPlaylistExpansionResult: SourceExpansionResult?
    private var settingsObserver: NSObjectProtocol?

    init(environment: AppEnvironment) {
        self.environment = environment
        registerSettingsObserver()
        Task {
            await loadModels()
            await loadDownloadDefaults()
            await loadPresentationPreferences()
        }
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func inspect() {
        Task {
            await performInspect()
        }
    }

    func copyTranscript() {
        Task {
            await runTranscriptTask(withSummary: false)
        }
    }

    func summarize() {
        Task {
            await runTranscriptTask(withSummary: true)
        }
    }

    func downloadVideo() {
        Task {
            await runDownloadTask(kind: .video)
        }
    }

    func downloadAudio() {
        Task {
            await runDownloadTask(kind: .audioOnly)
        }
    }

    func downloadSubtitle() {
        Task {
            await runDownloadTask(kind: .subtitle)
        }
    }

    func createBatchFromURLs() {
        Task {
            await runCreateBatchFromURLs()
        }
    }

    func expandPlaylistFromInputURL() {
        Task {
            await runPlaylistExpansion()
        }
    }

    func createBatchFromExpandedPlaylist() {
        Task {
            await runCreateBatchFromExpandedPlaylist()
        }
    }

    func selectAllExpandedPlaylistItems() {
        for index in expandedPlaylistItems.indices where expandedPlaylistItems[index].isValid {
            expandedPlaylistItems[index].isSelected = true
        }
    }

    func deselectAllExpandedPlaylistItems() {
        for index in expandedPlaylistItems.indices {
            expandedPlaylistItems[index].isSelected = false
        }
    }

    func clearPlaylistExpansionPreview() {
        playlistMetadata = nil
        expandedPlaylistItems = []
        playlistSkippedItems = []
        latestPlaylistExpansionResult = nil
    }

    func loadModels() async {
        availableModels = (try? await environment.modelDiscoveryService.discoverModels(for: selectedProvider)) ?? []
        selectedModelID = availableModels.first?.id ?? ""
    }

    func isLikelyPlaylistURL(_ input: String) -> Bool {
        environment.sourceExpansionService.isLikelyPlaylistURL(input)
    }

    var isLikelyPlaylistInput: Bool {
        environment.sourceExpansionService.isLikelyPlaylistURL(urlInput)
    }

    var selectedPlaylistItemCount: Int {
        expandedPlaylistItems.filter { $0.isValid && $0.isSelected }.count
    }

    private func loadDownloadDefaults() async {
        let settings = await environment.settingsRepository.loadSettings()
        outputDirectoryInput = settings.defaults.exportDirectory
        resumeDownloadsEnabled = settings.defaults.resumeDownloadsEnabled
        overwritePolicy = settings.defaults.overwritePolicy
        preferredVideoQuality = settings.defaults.videoQuality
        defaultSummaryLanguage = settings.defaults.summaryLanguage
        defaultSummaryMode = settings.defaults.summaryMode
        defaultSummaryLength = settings.defaults.summaryLength
    }

    private func loadPresentationPreferences() async {
        let settings = await environment.settingsRepository.loadSettings()
        isAdvancedMode = !settings.simpleModeEnabled
    }

    private func performInspect() async {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http") else {
            let mapped = ErrorPresentationMapper.map(
                URLError(.badURL),
                context: "OnlineInspection"
            )
            latestError = mapped
            statusMessage = mapped.message
            return
        }

        isInspecting = true
        defer { isInspecting = false }

        do {
            let source = MediaSource(type: .url, value: trimmed)
            let result = try await environment.mediaInspectionService.inspect(source: source)
            metadata = result
            selectedSubtitleTrackID = result.subtitleTracks.first?.id
            selectedVideoFormatID = defaultVideoFormatID(from: result) ?? ""
            selectedAudioFormatID = result.audioOptions.first?.formatID ?? ""
            canOfferTranscriptionFallback = result.subtitleTracks.isEmpty
            latestError = nil
            statusMessage = "Inspection complete"
            lastOperationSummary = "Inspect succeeded | source=url | subtitles=\(result.subtitleTracks.count) | videoFormats=\(result.videoOptions.count) | audioFormats=\(result.audioOptions.count)"
        } catch {
            metadata = nil
            canOfferTranscriptionFallback = false
            let mapped = ErrorPresentationMapper.map(error, context: "OnlineInspection")
            latestError = mapped
            statusMessage = mapped.message
            lastOperationSummary = "Inspect failed | code=\(mapped.code) | service=\(mapped.service)"
            environment.logger.error("Online inspection error: \(mapped.diagnostics ?? inspectionDiagnostics(from: error))")
        }
    }

    private func runCreateBatchFromURLs() async {
        guard !batchURLsInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let mapped = UserFacingError(
                title: "Batch Input Required",
                message: "Paste one URL per line to create a batch.",
                code: "BATCH_URL_INPUT_EMPTY",
                service: "BatchCreation",
                suggestions: [.retry]
            )
            latestError = mapped
            statusMessage = mapped.message
            return
        }

        isCreatingBatch = true
        defer { isCreatingBatch = false }

        do {
            let expansion = try await environment.sourceExpansionService.expand(
                request: SourceExpansionRequest(
                    source: .urlTextBlob(batchURLsInput),
                    sourceTypeHint: .multiURL,
                    deduplicationPolicy: .normalizedURL,
                    selectionDefault: .selectAllValid
                )
            )

            let settings = await environment.settingsRepository.loadSettings()
            let template = makeBatchTemplate(from: settings)
            let request = try environment.expandedSourceMapper.mapToBatchCreationRequest(
                expansionResult: expansion,
                operationTemplate: template,
                preferredTitle: nil
            )
            let batch = try await environment.batchCreationService.createBatch(request: request)
            await environment.batchExecutionService.start(batchJobID: batch.id)
            latestError = nil
            statusMessage = "Batch created: \(batch.totalCount) items (\(expansion.skippedCount) skipped)"
            lastOperationSummary = "Batch started | id=\(batch.id.uuidString) | count=\(batch.totalCount) | operation=\(batchOperationType.rawValue)"
            NotificationCenter.default.post(
                name: .appOpenBatchRequested,
                object: nil,
                userInfo: ["batchID": batch.id]
            )
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "BatchCreation")
            latestError = mapped
            statusMessage = mapped.message
            lastOperationSummary = "Batch creation failed | code=\(mapped.code) | service=\(mapped.service)"
        }
    }

    private func runPlaylistExpansion() async {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let mapped = UserFacingError(
                title: "Playlist URL Required",
                message: "Enter a playlist URL before running expansion.",
                code: "PLAYLIST_URL_EMPTY",
                service: "SourceExpansion",
                suggestions: [.verifyURL]
            )
            latestError = mapped
            statusMessage = mapped.message
            return
        }

        isExpandingPlaylist = true
        defer { isExpandingPlaylist = false }

        do {
            let result = try await environment.sourceExpansionService.expand(
                request: SourceExpansionRequest(
                    source: .playlistURL(trimmed),
                    sourceTypeHint: .playlistURL,
                    deduplicationPolicy: .normalizedURL,
                    selectionDefault: .selectAllValid
                )
            )

            playlistMetadata = result.playlistMetadata
            expandedPlaylistItems = result.expandedItems
            playlistSkippedItems = result.skippedItems
            latestPlaylistExpansionResult = result
            latestError = nil
            statusMessage = "Playlist expanded: \(result.expandedItems.count) valid · \(result.skippedItems.count) skipped"
            lastOperationSummary = "Playlist expansion succeeded | selected=\(result.selectedCount) | valid=\(result.validCount) | skipped=\(result.skippedCount)"
        } catch {
            clearPlaylistExpansionPreview()
            let mapped = ErrorPresentationMapper.map(error, context: "PlaylistExpansion")
            latestError = mapped
            statusMessage = mapped.message
            lastOperationSummary = "Playlist expansion failed | code=\(mapped.code) | service=\(mapped.service)"
        }
    }

    private func runCreateBatchFromExpandedPlaylist() async {
        guard playlistMetadata != nil, !expandedPlaylistItems.isEmpty else {
            let mapped = UserFacingError(
                title: "Expand Playlist First",
                message: "Run playlist expansion before creating a batch.",
                code: "PLAYLIST_EXPANSION_MISSING",
                service: "BatchCreation",
                suggestions: [.retry]
            )
            latestError = mapped
            statusMessage = mapped.message
            return
        }

        isCreatingBatch = true
        defer { isCreatingBatch = false }

        do {
            let settings = await environment.settingsRepository.loadSettings()
            let template = makeBatchTemplate(from: settings)
            let selectionApplied = makePlaylistExpansionResultFromCurrentSelection()
            let title = playlistMetadata.map { "\(batchOperationType.rawValue.capitalized) Playlist Batch (\($0.title))" }
            let request = try environment.expandedSourceMapper.mapToBatchCreationRequest(
                expansionResult: selectionApplied,
                operationTemplate: template,
                preferredTitle: title
            )

            let batch = try await environment.batchCreationService.createBatch(request: request)
            await environment.batchExecutionService.start(batchJobID: batch.id)
            latestError = nil
            statusMessage = "Playlist batch created: \(batch.totalCount) items"
            lastOperationSummary = "Playlist batch started | id=\(batch.id.uuidString) | selected=\(selectionApplied.selectedCount) | skipped=\(selectionApplied.skippedCount)"
            NotificationCenter.default.post(
                name: .appOpenBatchRequested,
                object: nil,
                userInfo: ["batchID": batch.id]
            )
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "PlaylistBatchCreation")
            latestError = mapped
            statusMessage = mapped.message
            lastOperationSummary = "Playlist batch creation failed | code=\(mapped.code) | service=\(mapped.service)"
        }
    }

    private func makePlaylistExpansionResultFromCurrentSelection() -> SourceExpansionResult {
        SourceExpansionResult(
            sourceKind: .playlistURL,
            sourceURL: playlistMetadata?.sourceURL ?? urlInput.trimmingCharacters(in: .whitespacesAndNewlines),
            playlistMetadata: playlistMetadata,
            status: expandedPlaylistItems.isEmpty ? .empty : (playlistSkippedItems.isEmpty ? .ready : .partial),
            expandedItems: expandedPlaylistItems,
            skippedItems: playlistSkippedItems,
            diagnostics: latestPlaylistExpansionResult?.diagnostics
        )
    }

    private func makeBatchTemplate(from settings: AppSettings) -> BatchOperationTemplate {
        let defaultsTemplate = BatchOperationTemplate.fromDefaults(
            operationType: batchOperationType,
            defaults: settings.defaults
        )
        let normalizedOutput = outputDirectoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return BatchOperationTemplate(
            operationType: defaultsTemplate.operationType,
            outputLanguage: defaultsTemplate.outputLanguage,
            summaryMode: defaultsTemplate.summaryMode,
            summaryLength: defaultsTemplate.summaryLength,
            provider: selectedProvider,
            modelID: selectedModelID.isEmpty ? defaultsTemplate.modelID : selectedModelID,
            summaryTemplateKind: defaultsTemplate.summaryTemplateKind,
            outputDirectory: normalizedOutput.isEmpty ? defaultsTemplate.outputDirectory : normalizedOutput,
            transcriptionBackend: defaultsTemplate.transcriptionBackend,
            openAITranscriptionModel: defaultsTemplate.openAITranscriptionModel,
            whisperExecutablePath: defaultsTemplate.whisperExecutablePath,
            whisperModelPath: defaultsTemplate.whisperModelPath,
            transcriptionLanguageHint: defaultsTemplate.transcriptionLanguageHint,
            transcriptOutputKinds: defaultsTemplate.transcriptOutputKinds,
            overwritePolicy: defaultsTemplate.overwritePolicy,
            resumeDownloadsEnabled: defaultsTemplate.resumeDownloadsEnabled,
            summaryChunkingStrategy: defaultsTemplate.summaryChunkingStrategy,
            summaryStructuredOutputPreferred: defaultsTemplate.summaryStructuredOutputPreferred,
            summaryOutputFormat: defaultsTemplate.summaryOutputFormat,
            maxConcurrentItems: defaultsTemplate.maxConcurrentItems
        )
    }

    private func runDownloadTask(kind: DownloadKind) async {
        guard let metadata else {
            latestError = nil
            statusMessage = "Inspect media first"
            return
        }

        let selection = DownloadSelection(
            kind: kind,
            videoFormatID: selectedVideoFormatID.isEmpty ? nil : selectedVideoFormatID,
            audioFormatID: selectedAudioFormatID.isEmpty ? nil : selectedAudioFormatID,
            subtitleTrack: selectedSubtitleTrack
        )

        do {
            try selection.validate(against: metadata)
            latestError = nil
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "DownloadValidation")
            latestError = mapped
            statusMessage = mapped.message
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let coordinator = TaskExecutionCoordinator(
            taskRepository: environment.taskRepository,
            historyRepository: environment.historyRepository,
            artifactIndexingService: environment.artifactIndexingService,
            tempFileCleanupService: environment.tempFileCleanupService,
            logger: environment.logger,
            notificationService: environment.notificationService
        )

        var task = TaskItem(source: metadata.source, taskType: .export)
        await coordinator.addTask(task)

        let request = MediaDownloadRequest(
            source: metadata.source,
            kind: kind,
            metadataTitle: metadata.title,
            selectedVideoFormatID: selection.videoFormatID,
            selectedAudioFormatID: selection.audioFormatID,
            selectedSubtitleTrack: selection.subtitleTrack,
            outputDirectory: outputDirectoryInput,
            preferredFileName: nil,
            resumeEnabled: resumeDownloadsEnabled,
            overwritePolicy: overwritePolicy,
            preferredSubtitleFormat: kind == .subtitle ? preferredSubtitleFormat : nil
        )

        let taskID = task.id

        do {
            task = await coordinator.updateTask(
                task,
                status: .running,
                progress: TaskProgressFactory.step(0.03, description: "Preparing download")
            )

            let result = try await environment.mediaDownloadService.download(
                request: request,
                progressHandler: { progress in
                    Task {
                        if let current = await self.environment.taskRepository.task(id: taskID) {
                            _ = await coordinator.updateTask(
                                current,
                                status: .running,
                                progress: progress
                            )
                        }
                    }
                }
            )

            let latestTask = await environment.taskRepository.task(id: taskID) ?? task
            await coordinator.completeTask(
                latestTask,
                transcript: nil,
                summary: nil,
                downloadResult: result
            )
            latestError = nil
            statusMessage = "Download completed: \(result.outputFileName)"
            lastOperationSummary = "Export succeeded | kind=\(kind.rawValue) | output=\(result.outputPath)"
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "Download")
            let taskError = TaskError(code: mapped.code, message: mapped.message, technicalDetails: mapped.diagnostics)
            await coordinator.failTask(task, error: taskError)
            latestError = mapped
            statusMessage = taskError.message
            lastOperationSummary = "Export failed | step=\(task.progress.currentStep) | code=\(mapped.code)"
            environment.logger.error("Download failed: \(taskError.technicalDetails ?? taskError.message)")
        }
    }

    private func runTranscriptTask(withSummary: Bool) async {
        guard let metadata else {
            latestError = nil
            statusMessage = "Inspect media first"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let taskType: TaskType = withSummary ? .summarize : .copyTranscript
        let coordinator = TaskExecutionCoordinator(
            taskRepository: environment.taskRepository,
            historyRepository: environment.historyRepository,
            artifactIndexingService: environment.artifactIndexingService,
            tempFileCleanupService: environment.tempFileCleanupService,
            logger: environment.logger,
            notificationService: environment.notificationService
        )

        var task = TaskItem(source: metadata.source, taskType: taskType)
        await coordinator.addTask(task)

        do {
            task = await coordinator.updateTask(
                task,
                status: .running,
                progress: TaskProgressFactory.step(0.15, description: "Preparing transcript")
            )

            try await Task.sleep(nanoseconds: 350_000_000)
            let transcript = try await environment.transcriptionService.transcribe(
                taskID: task.id,
                source: metadata.source,
                preferredLanguage: selectedSubtitleLanguage
            )
            latestTranscript = transcript

            task = await coordinator.updateTask(
                task,
                status: .running,
                progress: TaskProgressFactory.step(withSummary ? 0.6 : 0.95, description: withSummary ? "Generating summary" : "Finalizing")
            )

            var summary: SummaryResult?
            if withSummary {
                let request = SummaryRequest(
                    provider: selectedProvider,
                    modelID: selectedModelID,
                    mode: defaultSummaryMode,
                    length: defaultSummaryLength,
                    outputLanguage: defaultSummaryLanguage,
                    prompt: SummaryTemplateLibrary.studyTemplate
                )
                summary = try await environment.summarizationService.summarize(
                    taskID: task.id,
                    transcript: transcript,
                    request: request
                )
            }

            await coordinator.completeTask(task, transcript: transcript, summary: summary)
            latestError = nil
            statusMessage = withSummary ? "Summary task completed" : "Transcript copied to history"
            if withSummary {
                lastOperationSummary = "Transcribe+Summarize succeeded | provider=\(selectedProvider.rawValue) | model=\(selectedModelID)"
            } else {
                lastOperationSummary = "Transcribe succeeded | source=url | backend=auto"
            }
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "OnlineTask")
            let taskError = TaskError(code: mapped.code, message: mapped.message, technicalDetails: mapped.diagnostics)
            await coordinator.failTask(task, error: taskError)
            latestError = mapped
            statusMessage = mapped.message
            lastOperationSummary = "Task failed | step=\(task.progress.currentStep) | code=\(mapped.code) | service=\(mapped.service)"
        }
    }

    private func registerSettingsObserver() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .appSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadPresentationPreferences()
                await self?.loadDownloadDefaults()
            }
        }
    }

    private var selectedSubtitleTrack: SubtitleTrack? {
        guard let id = selectedSubtitleTrackID else { return nil }
        return metadata?.subtitleTracks.first(where: { $0.id == id })
    }

    private var selectedSubtitleLanguage: String {
        selectedSubtitleTrack?.languageCode ?? "en"
    }

    private func defaultVideoFormatID(from metadata: MediaMetadata) -> String? {
        if let exact720 = metadata.videoOptions.first(where: {
            $0.qualityLabel.contains("720") || $0.height == 720
        }) {
            return exact720.formatID
        }

        if let preferred = metadata.videoOptions.first(where: {
            $0.qualityLabel.localizedCaseInsensitiveContains(preferredVideoQuality)
        }) {
            return preferred.formatID
        }

        return metadata.videoOptions
            .sorted { ($0.height ?? 0) > ($1.height ?? 0) }
            .first?
            .formatID
    }

    private func inspectionErrorMessage(from error: Error) -> String {
        if let inspectionError = error as? MediaInspectionError {
            return inspectionError.userMessage
        }
        return "Failed to inspect media."
    }

    private func inspectionDiagnostics(from error: Error) -> String {
        if let inspectionError = error as? MediaInspectionError {
            return inspectionError.diagnostics
        }
        return error.localizedDescription
    }

    private func downloadErrorMessage(from error: Error) -> String {
        if let downloadError = error as? DownloadError {
            return downloadError.userMessage
        }
        return error.localizedDescription
    }

    private func downloadDiagnostics(from error: Error) -> String {
        if let downloadError = error as? DownloadError {
            return downloadError.diagnostics
        }
        return error.localizedDescription
    }
}
