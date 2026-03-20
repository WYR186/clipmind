import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class BatchJobsViewModel: ObservableObject {
    @Published private(set) var batches: [BatchJob] = []
    @Published var selectedBatchID: BatchJobID? {
        didSet {
            observeSelectedBatchItems()
        }
    }
    @Published private(set) var selectedBatchItems: [BatchJobItem] = []
    @Published private(set) var relatedTasksByID: [UUID: TaskItem] = [:]
    @Published private(set) var artifactPathsByTaskID: [UUID: [String]] = [:]
    @Published private(set) var isAdvancedMode: Bool = false
    @Published var message: String = ""
    @Published var latestError: UserFacingError?

    private let environment: AppEnvironment
    private let decoder = JSONDecoder()
    private var batchObservationTask: Task<Void, Never>?
    private var itemObservationTask: Task<Void, Never>?
    private var taskObservationTask: Task<Void, Never>?
    private var settingsObserver: NSObjectProtocol?

    init(environment: AppEnvironment) {
        self.environment = environment
        observeBatches()
        observeTasks()
        registerSettingsObserver()
        Task { await loadPresentationPreferences() }
    }

    deinit {
        batchObservationTask?.cancel()
        itemObservationTask?.cancel()
        taskObservationTask?.cancel()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    var selectedBatch: BatchJob? {
        guard let selectedBatchID else {
            return nil
        }
        return batches.first(where: { $0.id == selectedBatchID })
    }

    func selectBatch(_ batchID: BatchJobID) {
        selectedBatchID = batchID
    }

    func startSelectedBatch() {
        guard let id = selectedBatchID else {
            return
        }

        Task {
            await environment.batchExecutionService.start(batchJobID: id)
            message = "Batch started"
        }
    }

    func cancelRemainingItems() {
        guard let id = selectedBatchID else {
            return
        }

        Task {
            await environment.batchExecutionService.cancelRemainingItems(batchJobID: id)
            message = "Remaining pending items cancelled"
        }
    }

    func pauseSelectedBatch() {
        guard let id = selectedBatchID else { return }
        Task {
            await environment.batchExecutionService.pause(batchJobID: id)
            message = "Pause requested — current items will complete before stopping"
        }
    }

    func resumeSelectedBatch() {
        guard let id = selectedBatchID else { return }
        Task {
            await environment.batchExecutionService.resume(batchJobID: id)
            message = "Batch resumed"
        }
    }

    func retryFailedItems() {
        guard let id = selectedBatchID else {
            return
        }

        Task {
            await environment.batchExecutionService.retryFailedItems(batchJobID: id)
            message = "Retrying failed items"
        }
    }

    func createTranslationBatchFromCompletedItems() {
        guard let selectedBatch else {
            return
        }

        let completedSources = selectedBatchItems
            .filter { $0.status == .completed }
            .map(\.source)

        guard !completedSources.isEmpty else {
            message = "No completed items available for translation batch."
            return
        }

        Task {
            let settings = await environment.settingsRepository.loadSettings()
            let defaultTemplate = BatchOperationTemplate.fromDefaults(
                operationType: .translate,
                defaults: settings.defaults
            )
            let base = selectedBatch.operationTemplate
            let template = BatchOperationTemplate(
                operationType: .translate,
                outputLanguage: base.outputLanguage,
                summaryMode: base.summaryMode,
                summaryLength: base.summaryLength,
                provider: base.provider,
                modelID: base.modelID,
                summaryTemplateKind: base.summaryTemplateKind,
                outputDirectory: base.outputDirectory ?? defaultTemplate.outputDirectory,
                transcriptionBackend: base.transcriptionBackend,
                openAITranscriptionModel: base.openAITranscriptionModel,
                whisperExecutablePath: base.whisperExecutablePath,
                whisperModelPath: base.whisperModelPath,
                transcriptionLanguageHint: base.transcriptionLanguageHint,
                transcriptOutputKinds: base.transcriptOutputKinds,
                overwritePolicy: base.overwritePolicy,
                resumeDownloadsEnabled: base.resumeDownloadsEnabled,
                summaryChunkingStrategy: base.summaryChunkingStrategy,
                summaryStructuredOutputPreferred: base.summaryStructuredOutputPreferred,
                summaryOutputFormat: base.summaryOutputFormat,
                translationTargetLanguage: base.translationTargetLanguage,
                translationMode: base.translationMode,
                translationStyle: base.translationStyle,
                translationBilingualOutputEnabled: base.translationBilingualOutputEnabled,
                translationPreserveTimestamps: base.translationPreserveTimestamps,
                translationPreserveTerminology: base.translationPreserveTerminology,
                translationOutputFormats: base.translationOutputFormats,
                maxConcurrentItems: base.maxConcurrentItems
            )

            let request = BatchCreationRequest(
                title: "Translate Batch (\(selectedBatch.title))",
                sourceType: selectedBatch.sourceType,
                sources: completedSources,
                operationTemplate: template,
                sourceDescriptor: selectedBatch.sourceDescriptor,
                sourceMetadataJSON: selectedBatch.sourceMetadataJSON
            )

            do {
                let batch = try await environment.batchCreationService.createBatch(request: request)
                await environment.batchExecutionService.start(batchJobID: batch.id)
                message = "Translation batch started (\(batch.totalCount) items)"
                NotificationCenter.default.post(
                    name: .appOpenBatchRequested,
                    object: nil,
                    userInfo: ["batchID": batch.id]
                )
            } catch {
                let mapped = ErrorPresentationMapper.map(error, context: "BatchTranslation")
                latestError = mapped
                message = mapped.message
            }
        }
    }

    func copySelectedSummary() {
        guard let batch = selectedBatch else {
            return
        }

        let summary = """
        Batch: \(batch.title)
        Status: \(batch.status.rawValue)
        Progress: \(Int(batch.progress.fractionCompleted * 100))%
        Completed: \(batch.completedCount)
        Failed: \(batch.failedCount)
        Running: \(batch.runningCount)
        Pending: \(batch.pendingCount)
        Cancelled: \(batch.cancelledCount)
        """

        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary, forType: .string)
        #endif
        message = "Batch summary copied"
    }

    func openTask(for item: BatchJobItem) {
        guard let taskID = item.taskID else {
            return
        }
        NotificationCenter.default.post(
            name: .appOpenTaskRequested,
            object: nil,
            userInfo: ["taskID": taskID]
        )
    }

    func outputPath(for item: BatchJobItem) -> String? {
        guard let taskID = item.taskID else {
            return nil
        }
        return relatedTasksByID[taskID]?.outputPath ?? artifactPathsByTaskID[taskID]?.first
    }

    func revealOutput(for item: BatchJobItem) {
        guard let path = outputPath(for: item) else {
            return
        }
        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        #endif
    }

    func sourceDescription(for batch: BatchJob) -> String? {
        if let metadata = playlistMetadata(for: batch) {
            return "Playlist: \(metadata.title)"
        }

        guard let descriptor = batch.sourceDescriptor?.trimmingCharacters(in: .whitespacesAndNewlines), !descriptor.isEmpty else {
            return nil
        }

        if descriptor.hasPrefix("playlist:") {
            let value = descriptor.replacingOccurrences(of: "playlist:", with: "")
            return "Playlist: \(value)"
        }
        return descriptor
    }

    func playlistMetadata(for batch: BatchJob) -> PlaylistMetadata? {
        guard let payload = batch.sourceMetadataJSON,
              let data = payload.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(PlaylistMetadata.self, from: data)
    }

    private func observeBatches() {
        batchObservationTask?.cancel()
        batchObservationTask = Task { [weak self] in
            guard let self else { return }
            let stream = await environment.batchJobRepository.batchStream()
            for await snapshot in stream {
                self.batches = snapshot
                if self.selectedBatchID == nil {
                    self.selectedBatchID = snapshot.first?.id
                }
            }
        }
    }

    private func observeSelectedBatchItems() {
        itemObservationTask?.cancel()

        guard let batchID = selectedBatchID else {
            selectedBatchItems = []
            artifactPathsByTaskID = [:]
            return
        }

        itemObservationTask = Task { [weak self] in
            guard let self else { return }
            let stream = await environment.batchJobRepository.itemStream(forBatchID: batchID)
            for await snapshot in stream {
                self.selectedBatchItems = snapshot
                await self.refreshArtifacts(for: snapshot)
            }
        }
    }

    private func observeTasks() {
        taskObservationTask?.cancel()
        taskObservationTask = Task { [weak self] in
            guard let self else { return }
            let stream = await environment.taskRepository.taskStream()
            for await snapshot in stream {
                var mapping: [UUID: TaskItem] = [:]
                for task in snapshot {
                    mapping[task.id] = task
                }
                self.relatedTasksByID = mapping
            }
        }
    }

    private func refreshArtifacts(for items: [BatchJobItem]) async {
        var mapping: [UUID: [String]] = [:]
        for item in items {
            guard let taskID = item.taskID else { continue }
            let artifacts = await environment.artifactRepository.artifacts(forTaskID: taskID)
            mapping[taskID] = artifacts.map(\.filePath)
        }
        artifactPathsByTaskID = mapping
    }

    private func loadPresentationPreferences() async {
        let settings = await environment.settingsRepository.loadSettings()
        isAdvancedMode = !settings.simpleModeEnabled
    }

    private func registerSettingsObserver() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .appSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadPresentationPreferences()
            }
        }
    }
}
