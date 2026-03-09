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

    @Published var isInspecting: Bool = false
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = ""
    @Published private(set) var canOfferTranscriptionFallback: Bool = false

    @Published var selectedProvider: ProviderType = .openAI
    @Published var availableModels: [ModelDescriptor] = []
    @Published var selectedModelID: String = ""

    @Published var resumeDownloadsEnabled: Bool = true
    @Published var overwritePolicy: FileOverwritePolicy = .renameIfNeeded

    private let environment: AppEnvironment
    private var latestTranscript: TranscriptItem?
    private var preferredVideoQuality: String = "720p"

    init(environment: AppEnvironment) {
        self.environment = environment
        Task {
            await loadModels()
            await loadDownloadDefaults()
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

    func loadModels() async {
        availableModels = (try? await environment.modelDiscoveryService.discoverModels(for: selectedProvider)) ?? []
        selectedModelID = availableModels.first?.id ?? ""
    }

    private func loadDownloadDefaults() async {
        let settings = await environment.settingsRepository.loadSettings()
        outputDirectoryInput = settings.defaults.exportDirectory
        resumeDownloadsEnabled = settings.defaults.resumeDownloadsEnabled
        overwritePolicy = settings.defaults.overwritePolicy
        preferredVideoQuality = settings.defaults.videoQuality
    }

    private func performInspect() async {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http") else {
            statusMessage = "Please input a valid URL"
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
            statusMessage = "Inspection complete"
        } catch {
            metadata = nil
            canOfferTranscriptionFallback = false
            statusMessage = inspectionErrorMessage(from: error)
            environment.logger.error("Online inspection error: \(inspectionDiagnostics(from: error))")
        }
    }

    private func runDownloadTask(kind: DownloadKind) async {
        guard let metadata else {
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
        } catch {
            statusMessage = downloadErrorMessage(from: error)
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let coordinator = TaskExecutionCoordinator(
            taskRepository: environment.taskRepository,
            historyRepository: environment.historyRepository,
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
            statusMessage = "Download completed: \(result.outputFileName)"
        } catch {
            let taskError = TaskError(
                code: "DOWNLOAD_FAILED",
                message: downloadErrorMessage(from: error),
                technicalDetails: downloadDiagnostics(from: error)
            )
            await coordinator.failTask(task, error: taskError)
            statusMessage = taskError.message
            environment.logger.error("Download failed: \(taskError.technicalDetails ?? taskError.message)")
        }
    }

    private func runTranscriptTask(withSummary: Bool) async {
        guard let metadata else {
            statusMessage = "Inspect media first"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let taskType: TaskType = withSummary ? .summarize : .copyTranscript
        let coordinator = TaskExecutionCoordinator(
            taskRepository: environment.taskRepository,
            historyRepository: environment.historyRepository,
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
                    mode: .keyPoints,
                    length: .medium,
                    outputLanguage: "zh",
                    prompt: SummaryTemplateLibrary.studyTemplate
                )
                summary = try await environment.summarizationService.summarize(
                    taskID: task.id,
                    transcript: transcript,
                    request: request
                )
            }

            await coordinator.completeTask(task, transcript: transcript, summary: summary)
            statusMessage = withSummary ? "Summary task completed" : "Transcript copied to history"
        } catch {
            let taskError = TaskError(code: "ONLINE_TASK_FAILED", message: error.localizedDescription)
            await coordinator.failTask(task, error: taskError)
            statusMessage = "Task failed"
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
