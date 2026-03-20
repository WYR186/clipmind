import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class TasksViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var selectedTaskID: UUID?
    @Published private(set) var isAdvancedMode: Bool = false
    @Published private(set) var taskHistoryByTaskID: [UUID: HistoryEntry] = [:]

    private let environment: AppEnvironment
    private var observationTask: Task<Void, Never>?
    private var historyObservationTask: Task<Void, Never>?
    private var settingsObserver: NSObjectProtocol?

    init(environment: AppEnvironment) {
        self.environment = environment
        registerSettingsObserver()
        observeTasks()
        observeHistory()
        Task { await loadPresentationPreferences() }
    }

    deinit {
        observationTask?.cancel()
        historyObservationTask?.cancel()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    var selectedTask: TaskItem? {
        guard let selectedTaskID else { return nil }
        return tasks.first(where: { $0.id == selectedTaskID })
    }

    func selectTask(_ taskID: UUID) {
        selectedTaskID = taskID
    }

    func relatedHistoryEntry(for task: TaskItem) -> HistoryEntry? {
        taskHistoryByTaskID[task.id]
    }

    func operationSummary(for task: TaskItem) -> String {
        let history = relatedHistoryEntry(for: task)
        let provider = history?.summary?.provider.rawValue ?? "n/a"
        let transcriptBackend = history?.transcript?.backend?.rawValue ?? "n/a"
        let transcriptSource = history?.transcript?.sourceType.rawValue ?? "n/a"
        return "Step: \(task.progress.currentStep) | Provider: \(provider) | Transcript source: \(transcriptSource) | Transcript backend: \(transcriptBackend) | Updated: \(task.updatedAt.shortDateTime())"
    }

    func failureStep(for task: TaskItem) -> String? {
        guard task.status == .failed else { return nil }
        return task.progress.currentStep
    }

    func artifactLocations(for task: TaskItem) -> [String] {
        guard let history = relatedHistoryEntry(for: task) else {
            return task.outputPath.map { [$0] } ?? []
        }

        var values: [String] = []
        if let outputPath = history.downloadResult?.outputPath {
            values.append(outputPath)
        }
        if let transcript = history.transcript {
            values.append(contentsOf: transcript.artifacts.map(\.path))
        }
        if let summary = history.summary {
            values.append(contentsOf: summary.artifacts.map(\.path))
        }
        if values.isEmpty, let outputPath = task.outputPath {
            values.append(outputPath)
        }
        return Array(NSOrderedSet(array: values)) as? [String] ?? values
    }

    func revealArtifact(path: String) {
        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        #endif
    }

    private func observeTasks() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            let stream = await environment.taskRepository.taskStream()
            for await snapshot in stream {
                self.tasks = snapshot
                if self.selectedTaskID == nil {
                    self.selectedTaskID = snapshot.first?.id
                }
            }
        }
    }

    private func observeHistory() {
        historyObservationTask?.cancel()
        historyObservationTask = Task { [weak self] in
            guard let self else { return }
            let stream = await environment.historyRepository.historyStream()
            for await snapshot in stream {
                var mapping: [UUID: HistoryEntry] = [:]
                for entry in snapshot {
                    guard let taskID = entry.taskID else { continue }
                    mapping[taskID] = entry
                }
                self.taskHistoryByTaskID = mapping
            }
        }
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
