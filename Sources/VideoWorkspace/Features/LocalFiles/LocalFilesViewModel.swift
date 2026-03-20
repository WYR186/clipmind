import Foundation

@MainActor
final class LocalFilesViewModel: ObservableObject {
    @Published var filePathInput: String = MockSamples.localPath
    @Published var batchFilePaths: [String] = []
    @Published var batchOperationType: BatchOperationType = .transcribe
    @Published var isCreatingBatch: Bool = false
    @Published var outputDirectoryInput: String = ""
    @Published var metadata: MediaMetadata?
    @Published var isInspecting: Bool = false
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = ""
    @Published var lastOperationSummary: String = ""
    @Published var latestError: UserFacingError?
    @Published private(set) var isAdvancedMode: Bool = false

    @Published var selectedTranscriptionBackend: TranscriptionBackend = .whisperCPP
    @Published var openAIModelID: String = "gpt-4o-mini-transcribe"
    @Published var whisperExecutablePath: String = ""
    @Published var whisperModelPath: String = ""
    @Published var transcriptionLanguageHint: String = "en"
    @Published var transcriptionPromptHint: String = ""
    @Published var transcriptionTemperatureInput: String = ""
    @Published var preprocessingEnabled: Bool = true
    @Published var overwritePolicy: FileOverwritePolicy = .renameIfNeeded
    @Published var exportTXT: Bool = true
    @Published var exportSRT: Bool = true
    @Published var exportVTT: Bool = true

    @Published var transcriptPreview: String = ""
    @Published var transcriptArtifacts: [TranscriptArtifact] = []

    @Published var selectedProvider: ProviderType = .openAI
    @Published var selectedModelID: String = ""
    @Published var availableModels: [ModelDescriptor] = []
    @Published var selectedSummaryTemplateKind: SummaryPromptTemplateKind = .general
    @Published var selectedSummaryMode: SummaryMode = .abstractSummary
    @Published var selectedSummaryLength: SummaryLength = .medium
    @Published var summaryOutputLanguage: String = "en"
    @Published var summaryOutputFormat: SummaryOutputFormat = .markdown
    @Published var summaryChunkingStrategy: SummaryChunkingStrategy = .segmentAware
    @Published var summaryStructuredOutputPreferred: Bool = true
    @Published var customSummaryPrompt: String = ""
    @Published var summaryPreview: String = ""

    private let environment: AppEnvironment
    private var latestTranscript: TranscriptItem?
    private var settingsObserver: NSObjectProtocol?

    init(environment: AppEnvironment) {
        self.environment = environment
        ensureSampleFileExists(at: filePathInput)
        registerSettingsObserver()
        Task {
            await loadTranscriptionDefaults()
            await loadModels()
            await loadPresentationPreferences()
        }
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func useSampleFile() {
        filePathInput = MockSamples.localPath
        ensureSampleFileExists(at: filePathInput)
    }

    func inspect() {
        Task {
            await performInspect()
        }
    }

    func transcribe() {
        Task {
            await runLocalTask(withSummary: false)
        }
    }

    func summarize() {
        Task {
            await runLocalTask(withSummary: true)
        }
    }

    func setBatchFiles(urls: [URL]) {
        let values = urls.map { $0.path }.sorted()
        batchFilePaths = Array(NSOrderedSet(array: values)) as? [String] ?? values
    }

    func createBatchFromSelectedFiles() {
        Task {
            await runCreateBatchFromSelectedFiles()
        }
    }

    func loadModels() async {
        availableModels = (try? await environment.modelDiscoveryService.discoverModels(for: selectedProvider)) ?? []
        if selectedModelID.isEmpty {
            selectedModelID = availableModels.first?.id ?? ""
        }
    }

    func loadTranscriptionDefaults() async {
        let settings = await environment.settingsRepository.loadSettings()
        outputDirectoryInput = settings.defaults.exportDirectory

        selectedTranscriptionBackend = settings.defaults.transcriptionBackend
        openAIModelID = settings.defaults.openAITranscriptionModel
        whisperExecutablePath = settings.defaults.whisperExecutablePath
        whisperModelPath = settings.defaults.whisperModelPath
        transcriptionLanguageHint = settings.defaults.transcriptionLanguageHint
        preprocessingEnabled = settings.defaults.transcriptionPreprocessingEnabled
        overwritePolicy = settings.defaults.overwritePolicy

        let formats = Set(settings.defaults.transcriptOutputFormats)
        exportTXT = formats.contains(.txt)
        exportSRT = formats.contains(.srt)
        exportVTT = formats.contains(.vtt)

        selectedProvider = settings.defaults.summaryProvider
        selectedModelID = settings.defaults.summaryModelID
        selectedSummaryTemplateKind = settings.defaults.summaryTemplateKind
        selectedSummaryMode = settings.defaults.summaryMode
        selectedSummaryLength = settings.defaults.summaryLength
        summaryOutputLanguage = settings.defaults.summaryLanguage
        summaryOutputFormat = settings.defaults.summaryOutputFormat
        summaryChunkingStrategy = settings.defaults.summaryChunkingStrategy
        summaryStructuredOutputPreferred = settings.defaults.summaryStructuredOutputPreferred
    }

    private func loadPresentationPreferences() async {
        let settings = await environment.settingsRepository.loadSettings()
        isAdvancedMode = !settings.simpleModeEnabled
    }

    private func performInspect() async {
        let trimmed = filePathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let mapped = UserFacingError(
                title: "Path Required",
                message: "Provide a local file path before inspection.",
                code: "LOCAL_PATH_EMPTY",
                service: "LocalInspection",
                suggestions: [.retry]
            )
            latestError = mapped
            statusMessage = mapped.message
            return
        }

        isInspecting = true
        defer { isInspecting = false }

        do {
            let source = MediaSource(type: .localFile, value: trimmed)
            metadata = try await environment.mediaInspectionService.inspect(source: source)
            latestError = nil
            statusMessage = "Local file inspected"
            lastOperationSummary = "Inspect succeeded | source=local | videoStreams=\(metadata?.videoOptions.count ?? 0) | audioStreams=\(metadata?.audioOptions.count ?? 0)"
        } catch {
            metadata = nil
            let mapped = ErrorPresentationMapper.map(error, context: "LocalInspection")
            latestError = mapped
            statusMessage = mapped.message
            lastOperationSummary = "Inspect failed | code=\(mapped.code) | service=\(mapped.service)"
            environment.logger.error("Local inspection error: \(mapped.diagnostics ?? inspectionDiagnostics(from: error))")
        }
    }

    private func runLocalTask(withSummary: Bool) async {
        guard let metadata else {
            latestError = nil
            statusMessage = "Inspect local file first"
            return
        }

        let outputKinds = selectedOutputKinds()
        guard !outputKinds.isEmpty else {
            let mapped = UserFacingError(
                title: "Output Format Required",
                message: "Select at least one transcript output format.",
                code: "TRANSCRIPT_OUTPUT_EMPTY",
                service: "Transcription",
                suggestions: [.retry]
            )
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

        let type: TaskType = withSummary ? .summarize : .transcribe
        var task = TaskItem(source: metadata.source, taskType: type)
        await coordinator.addTask(task)

        let request = TranscriptionRequest(
            taskID: task.id,
            sourcePath: metadata.source.value,
            sourceType: .localFile,
            backend: selectedTranscriptionBackend,
            modelIdentifier: modelIdentifierForSelectedBackend(),
            outputKinds: outputKinds,
            languageHint: normalizedLanguageHint(),
            promptHint: normalizedPromptHint(),
            temperature: normalizedTemperature(),
            outputDirectory: outputDirectoryInput,
            overwritePolicy: overwritePolicy,
            preprocessingRequired: preprocessingEnabled,
            debugDiagnosticsEnabled: isAdvancedMode,
            whisperExecutablePath: whisperExecutablePath,
            whisperModelPath: whisperModelPath
        )

        let taskID = task.id

        do {
            task = await coordinator.updateTask(
                task,
                status: .running,
                progress: TaskProgressFactory.step(0.05, description: "Preparing transcription")
            )

            let transcriptionResult = try await environment.transcriptionService.transcribe(
                request: request,
                progressHandler: { progress in
                    Task {
                        if let current = await self.environment.taskRepository.task(id: taskID) {
                            let adjustedProgress = withSummary
                                ? TaskProgress(
                                    fractionCompleted: progress.fractionCompleted * 0.55,
                                    currentStep: "Transcription: \(progress.currentStep)"
                                )
                                : progress
                            _ = await coordinator.updateTask(
                                current,
                                status: .running,
                                progress: adjustedProgress
                            )
                        }
                    }
                }
            )

            let transcript = transcriptionResult.transcript
            latestTranscript = transcript
            transcriptPreview = String(transcript.content.prefix(700))
            transcriptArtifacts = transcriptionResult.artifacts

            var summary: SummaryResult?
            if withSummary {
                task = await coordinator.updateTask(
                    task,
                    status: .running,
                    progress: TaskProgressFactory.step(0.6, description: "Summarizing")
                )

                let summaryRequest = SummaryRequest(
                    provider: selectedProvider,
                    modelID: selectedModelID,
                    mode: selectedSummaryMode,
                    length: selectedSummaryLength,
                    outputLanguage: summaryOutputLanguage,
                    prompt: customSummaryPrompt,
                    templateKind: selectedSummaryTemplateKind,
                    customPromptOverride: customSummaryPrompt.isEmpty ? nil : customSummaryPrompt,
                    chunkingStrategy: summaryChunkingStrategy,
                    structuredOutputPreferred: summaryStructuredOutputPreferred,
                    outputFormat: summaryOutputFormat,
                    debugDiagnosticsEnabled: isAdvancedMode
                )

                summary = try await environment.summarizationService.summarize(
                    request: SummarizationRequest(
                        taskID: task.id,
                        transcript: transcript,
                        summaryRequest: summaryRequest
                    ),
                    progressHandler: { progress in
                        Task {
                            if let current = await self.environment.taskRepository.task(id: taskID) {
                                let adjustedProgress = TaskProgress(
                                    fractionCompleted: 0.55 + progress.fractionCompleted * 0.45,
                                    currentStep: "Summary: \(progress.currentStep)"
                                )
                                _ = await coordinator.updateTask(
                                    current,
                                    status: .running,
                                    progress: adjustedProgress
                                )
                            }
                        }
                    }
                )
                summaryPreview = String((summary?.content ?? "").prefix(900))
            }

            let latestTask = await environment.taskRepository.task(id: taskID) ?? task
            await coordinator.completeTask(
                latestTask,
                transcript: transcript,
                summary: summary,
                outputPath: transcriptionResult.artifacts.first?.path
            )
            latestError = nil
            statusMessage = withSummary ? "Local summary completed" : "Local transcription completed"
            if withSummary {
                lastOperationSummary = "Transcribe+Summarize succeeded | backend=\(selectedTranscriptionBackend.rawValue) | provider=\(selectedProvider.rawValue) | model=\(selectedModelID)"
            } else {
                lastOperationSummary = "Transcribe succeeded | backend=\(selectedTranscriptionBackend.rawValue) | outputs=\(transcriptionResult.artifacts.count)"
            }
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "LocalTask")
            let taskError = TaskError(code: mapped.code, message: mapped.message, technicalDetails: mapped.diagnostics)
            await coordinator.failTask(task, error: taskError)
            latestError = mapped
            statusMessage = taskError.message
            lastOperationSummary = "Task failed | step=\(task.progress.currentStep) | code=\(mapped.code) | service=\(mapped.service)"
        }
    }

    private func runCreateBatchFromSelectedFiles() async {
        guard !batchFilePaths.isEmpty else {
            let mapped = UserFacingError(
                title: "Batch Files Required",
                message: "Select one or more local files before creating a batch.",
                code: "BATCH_LOCAL_FILES_EMPTY",
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
            let defaultsTemplate = BatchOperationTemplate.fromDefaults(
                operationType: batchOperationType,
                defaults: settings.defaults
            )
            let outputKinds = selectedOutputKinds()
            let normalizedOutput = outputDirectoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let template = BatchOperationTemplate(
                operationType: defaultsTemplate.operationType,
                outputLanguage: summaryOutputLanguage,
                summaryMode: selectedSummaryMode,
                summaryLength: selectedSummaryLength,
                provider: selectedProvider,
                modelID: selectedModelID.isEmpty ? defaultsTemplate.modelID : selectedModelID,
                summaryTemplateKind: selectedSummaryTemplateKind,
                outputDirectory: normalizedOutput.isEmpty ? defaultsTemplate.outputDirectory : normalizedOutput,
                transcriptionBackend: selectedTranscriptionBackend,
                openAITranscriptionModel: openAIModelID,
                whisperExecutablePath: whisperExecutablePath.isEmpty ? nil : whisperExecutablePath,
                whisperModelPath: whisperModelPath.isEmpty ? nil : whisperModelPath,
                transcriptionLanguageHint: transcriptionLanguageHint,
                transcriptOutputKinds: outputKinds.isEmpty ? defaultsTemplate.transcriptOutputKinds : outputKinds,
                overwritePolicy: overwritePolicy,
                resumeDownloadsEnabled: defaultsTemplate.resumeDownloadsEnabled,
                summaryChunkingStrategy: summaryChunkingStrategy,
                summaryStructuredOutputPreferred: summaryStructuredOutputPreferred,
                summaryOutputFormat: summaryOutputFormat,
                maxConcurrentItems: defaultsTemplate.maxConcurrentItems
            )

            let request = BatchCreationRequest(
                title: nil,
                sourceType: .localFilesBatch,
                sources: batchFilePaths.map { MediaSource(type: .localFile, value: $0) },
                operationTemplate: template
            )

            let batch = try await environment.batchCreationService.createBatch(request: request)
            await environment.batchExecutionService.start(batchJobID: batch.id)
            latestError = nil
            statusMessage = "Batch created: \(batch.totalCount) items"
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

    private func selectedOutputKinds() -> [TranscriptOutputKind] {
        var kinds: [TranscriptOutputKind] = []
        if exportTXT { kinds.append(.txt) }
        if exportSRT { kinds.append(.srt) }
        if exportVTT { kinds.append(.vtt) }
        return kinds
    }

    private func modelIdentifierForSelectedBackend() -> String {
        switch selectedTranscriptionBackend {
        case .openAI:
            return openAIModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "gpt-4o-mini-transcribe"
                : openAIModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        case .whisperCPP:
            let trimmedPath = whisperModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPath.isEmpty {
                return "whisper-model"
            }
            return URL(fileURLWithPath: trimmedPath).lastPathComponent
        }
    }

    private func normalizedLanguageHint() -> String? {
        let trimmed = transcriptionLanguageHint.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedPromptHint() -> String? {
        let trimmed = transcriptionPromptHint.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedTemperature() -> Double? {
        let trimmed = transcriptionTemperatureInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private func ensureSampleFileExists(at path: String) {
        let manager = FileManager.default
        if manager.fileExists(atPath: path) {
            return
        }

        let data = Data("mock-media".utf8)
        manager.createFile(atPath: path, contents: data)
    }

    private func inspectionErrorMessage(from error: Error) -> String {
        if let inspectionError = error as? MediaInspectionError {
            return inspectionError.userMessage
        }
        return "Failed to inspect local media."
    }

    private func inspectionDiagnostics(from error: Error) -> String {
        if let inspectionError = error as? MediaInspectionError {
            return inspectionError.diagnostics
        }
        return error.localizedDescription
    }

    private func transcriptionErrorMessage(from error: Error) -> String {
        if let transcriptionError = error as? TranscriptionError {
            return transcriptionError.userMessage
        }
        return "Transcription failed."
    }

    private func transcriptionDiagnostics(from error: Error) -> String {
        if let transcriptionError = error as? TranscriptionError {
            return transcriptionError.diagnostics
        }
        return error.localizedDescription
    }

    private func registerSettingsObserver() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .appSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadPresentationPreferences()
                await self?.loadTranscriptionDefaults()
            }
        }
    }
}
