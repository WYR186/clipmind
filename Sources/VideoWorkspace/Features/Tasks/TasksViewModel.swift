import Foundation

@MainActor
final class TasksViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var selectedTaskID: UUID?

    private let environment: AppEnvironment
    private var observationTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
        observeTasks()
    }

    deinit {
        observationTask?.cancel()
    }

    var selectedTask: TaskItem? {
        guard let selectedTaskID else { return nil }
        return tasks.first(where: { $0.id == selectedTaskID })
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
}
