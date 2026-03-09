import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var recentTasks: [TaskItem] = []
    @Published private(set) var completedCount: Int = 0
    @Published private(set) var failedCount: Int = 0
    @Published private(set) var historyCount: Int = 0

    private let environment: AppEnvironment
    private var taskObservation: Task<Void, Never>?
    private var historyObservation: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
        observeTasks()
        observeHistory()
    }

    deinit {
        taskObservation?.cancel()
        historyObservation?.cancel()
    }

    private func observeTasks() {
        taskObservation?.cancel()
        taskObservation = Task { [weak self] in
            guard let self else { return }
            let stream = await environment.taskRepository.taskStream()
            for await tasks in stream {
                self.recentTasks = Array(tasks.prefix(5))
                self.completedCount = tasks.filter { $0.status == .completed }.count
                self.failedCount = tasks.filter { $0.status == .failed }.count
            }
        }
    }

    private func observeHistory() {
        historyObservation?.cancel()
        historyObservation = Task { [weak self] in
            guard let self else { return }
            let stream = await environment.historyRepository.historyStream()
            for await entries in stream {
                self.historyCount = entries.count
            }
        }
    }
}
