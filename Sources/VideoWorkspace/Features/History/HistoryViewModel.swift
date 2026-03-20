import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class HistoryViewModel: ObservableObject {
    struct TranslationSheetSeed: Identifiable {
        let id = UUID()
        let source: MediaSource
        let transcript: TranscriptItem
        let defaultBilingual: Bool
    }

    @Published private(set) var entries: [HistoryEntry] = []
    @Published var selectedEntryID: UUID? {
        didSet {
            Task { await loadSelectedEntryArtifacts() }
        }
    }
    @Published private(set) var selectedEntryArtifacts: [ArtifactRecord] = []
    @Published private(set) var isAdvancedMode: Bool = false
    @Published var latestError: UserFacingError?
    @Published var translationSheetSeed: TranslationSheetSeed?

    @Published var selectedProvider: ProviderType = .openAI
    @Published var selectedModelID: String = ""
    @Published var availableModels: [ModelDescriptor] = []
    @Published var selectedTemplateKind: SummaryPromptTemplateKind = .general
    @Published var selectedMode: SummaryMode = .abstractSummary
    @Published var selectedLength: SummaryLength = .medium
    @Published var outputLanguage: String = "en"
    @Published var customPrompt: String = ""
    @Published var statusMessage: String = ""

    private let environment: AppEnvironment
    private var observationTask: Task<Void, Never>?
    private var settingsObserver: NSObjectProtocol?

    init(environment: AppEnvironment) {
        self.environment = environment
        registerSettingsObserver()
        observeHistory()
        Task {
            await loadDefaults()
            await loadModels()
            await loadPresentationPreferences()
        }
    }

    deinit {
        observationTask?.cancel()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    var selectedEntry: HistoryEntry? {
        guard let selectedEntryID else { return nil }
        return entries.first(where: { $0.id == selectedEntryID })
    }

    func loadModels() async {
        availableModels = (try? await environment.modelDiscoveryService.discoverModels(for: selectedProvider)) ?? []
        if selectedModelID.isEmpty {
            selectedModelID = availableModels.first?.id ?? ""
        }
    }

    func summarizeSelectedEntry() {
        Task {
            await runSummaryForSelectedEntry()
        }
    }

    func copyTranscriptToPasteboard() {
        guard let transcript = selectedEntry?.transcript else { return }
        copyToPasteboard(transcript.content)
    }

    func copySummaryToPasteboard() {
        guard let summary = selectedEntry?.summary else { return }
        copyToPasteboard(summary.content)
    }

    func copyTranslationToPasteboard() {
        guard let translation = selectedEntry?.translation else { return }
        copyToPasteboard(translation.translatedText)
    }

    func presentTranslationSheet(defaultBilingual: Bool) {
        guard let entry = selectedEntry, let transcript = entry.transcript else {
            let mapped = UserFacingError(
                title: "Transcript Required",
                message: "Select a history entry with transcript before translation.",
                code: "HISTORY_TRANSLATION_TRANSCRIPT_REQUIRED",
                service: "History",
                suggestions: [.retry]
            )
            latestError = mapped
            statusMessage = mapped.message
            return
        }
        translationSheetSeed = TranslationSheetSeed(
            source: entry.source,
            transcript: transcript,
            defaultBilingual: defaultBilingual
        )
    }

    func makeTranslationViewModel(seed: TranslationSheetSeed) -> TranslationViewModel {
        TranslationViewModel(
            environment: environment,
            source: seed.source,
            transcript: seed.transcript,
            defaultBilingual: seed.defaultBilingual
        )
    }

    func requestOpenRelatedTask() {
        guard let taskID = selectedEntry?.taskID else { return }
        NotificationCenter.default.post(
            name: .appOpenTaskRequested,
            object: nil,
            userInfo: ["taskID": taskID]
        )
    }

    func revealArtifact(path: String) {
        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        #endif
    }

    func operationSummary(for entry: HistoryEntry) -> String {
        let provider = entry.translation?.provider.rawValue ?? entry.summary?.provider.rawValue ?? "n/a"
        let translationModel = entry.translation?.modelID ?? "n/a"
        let transcriptBackend = entry.transcript?.backend?.rawValue ?? "n/a"
        let transcriptSource = entry.transcript?.sourceType.rawValue ?? "n/a"
        return "Provider: \(provider) | Translation model: \(translationModel) | Transcript backend: \(transcriptBackend) | Transcript source: \(transcriptSource) | Created: \(entry.createdAt.shortDateTime())"
    }

    private func loadDefaults() async {
        let settings = await environment.settingsRepository.loadSettings()
        selectedProvider = settings.defaults.summaryProvider
        selectedModelID = settings.defaults.summaryModelID
        selectedTemplateKind = settings.defaults.summaryTemplateKind
        selectedMode = settings.defaults.summaryMode
        selectedLength = settings.defaults.summaryLength
        outputLanguage = settings.defaults.summaryLanguage
    }

    private func loadPresentationPreferences() async {
        let settings = await environment.settingsRepository.loadSettings()
        isAdvancedMode = !settings.simpleModeEnabled
    }

    private func observeHistory() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            let stream = await environment.historyRepository.historyStream()
            for await snapshot in stream {
                self.entries = snapshot
                if self.selectedEntryID == nil {
                    self.selectedEntryID = snapshot.first?.id
                }
                await self.loadSelectedEntryArtifacts()
            }
        }
    }

    private func loadSelectedEntryArtifacts() async {
        guard let historyID = selectedEntryID else {
            selectedEntryArtifacts = []
            return
        }
        selectedEntryArtifacts = await environment.artifactRepository.artifacts(forHistoryID: historyID)
    }

    private func runSummaryForSelectedEntry() async {
        guard let entry = selectedEntry, let transcript = entry.transcript else {
            let mapped = UserFacingError(
                title: "Transcript Required",
                message: "Select a history entry with transcript before summarizing.",
                code: "HISTORY_TRANSCRIPT_REQUIRED",
                service: "History",
                suggestions: [.retry]
            )
            latestError = mapped
            statusMessage = mapped.message
            return
        }

        let coordinator = TaskExecutionCoordinator(
            taskRepository: environment.taskRepository,
            historyRepository: environment.historyRepository,
            artifactIndexingService: environment.artifactIndexingService,
            tempFileCleanupService: environment.tempFileCleanupService,
            logger: environment.logger,
            notificationService: environment.notificationService
        )

        let task = TaskItem(source: entry.source, taskType: .summarize)
        await coordinator.addTask(task)
        let taskID = task.id

        let request = SummaryRequest(
            provider: selectedProvider,
            modelID: selectedModelID,
            mode: selectedMode,
            length: selectedLength,
            outputLanguage: outputLanguage,
            prompt: customPrompt,
            templateKind: selectedTemplateKind,
            customPromptOverride: customPrompt.isEmpty ? nil : customPrompt,
            chunkingStrategy: .segmentAware,
            structuredOutputPreferred: true,
            outputFormat: .markdown,
            debugDiagnosticsEnabled: isAdvancedMode
        )

        do {
            let result = try await environment.summarizationService.summarize(
                request: SummarizationRequest(taskID: taskID, transcript: transcript, summaryRequest: request),
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
            await coordinator.completeTask(latestTask, transcript: transcript, summary: result)
            latestError = nil
            statusMessage = "Summary generated"
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "HistorySummary")
            latestError = mapped
            await coordinator.failTask(task, error: TaskError(code: mapped.code, message: mapped.message, technicalDetails: mapped.diagnostics))
            statusMessage = mapped.message
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
                await self?.loadDefaults()
            }
        }
    }

    private func copyToPasteboard(_ value: String) {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #endif
    }
}
