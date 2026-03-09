import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    @Published var selectedEntryID: UUID?

    @Published var selectedProvider: ProviderType = .openAI
    @Published var selectedModelID: String = ""
    @Published var availableModels: [ModelDescriptor] = []
    @Published var selectedTemplateKind: SummaryPromptTemplateKind = .general
    @Published var selectedMode: SummaryMode = .abstractSummary
    @Published var selectedLength: SummaryLength = .medium
    @Published var outputLanguage: String = "zh"
    @Published var customPrompt: String = ""
    @Published var statusMessage: String = ""

    private let environment: AppEnvironment
    private var observationTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
        observeHistory()
        Task {
            await loadDefaults()
            await loadModels()
        }
    }

    deinit {
        observationTask?.cancel()
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

    private func loadDefaults() async {
        let settings = await environment.settingsRepository.loadSettings()
        selectedProvider = settings.defaults.summaryProvider
        selectedModelID = settings.defaults.summaryModelID
        selectedTemplateKind = settings.defaults.summaryTemplateKind
        selectedMode = settings.defaults.summaryMode
        selectedLength = settings.defaults.summaryLength
        outputLanguage = settings.defaults.summaryLanguage
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
            }
        }
    }

    private func runSummaryForSelectedEntry() async {
        guard let entry = selectedEntry, let transcript = entry.transcript else {
            statusMessage = "Select an entry that contains transcript"
            return
        }

        let coordinator = TaskExecutionCoordinator(
            taskRepository: environment.taskRepository,
            historyRepository: environment.historyRepository,
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
            debugDiagnosticsEnabled: true
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
            statusMessage = "Summary generated"
        } catch {
            let details: String
            if let summaryError = error as? SummarizationError {
                details = summaryError.userMessage
            } else {
                details = error.localizedDescription
            }
            await coordinator.failTask(task, error: TaskError(code: "HISTORY_SUMMARY_FAILED", message: details))
            statusMessage = details
        }
    }
}
