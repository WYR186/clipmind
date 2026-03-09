import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    let environment: AppEnvironment
    let router: AppRouter

    @Published var isOnboardingPresented: Bool = true

    let dashboardViewModel: DashboardViewModel
    let onlineVideoViewModel: OnlineVideoViewModel
    let localFilesViewModel: LocalFilesViewModel
    let tasksViewModel: TasksViewModel
    let historyViewModel: HistoryViewModel
    let settingsViewModel: SettingsViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        self.router = AppRouter()

        dashboardViewModel = DashboardViewModel(environment: environment)
        onlineVideoViewModel = OnlineVideoViewModel(environment: environment)
        localFilesViewModel = LocalFilesViewModel(environment: environment)
        tasksViewModel = TasksViewModel(environment: environment)
        historyViewModel = HistoryViewModel(environment: environment)
        settingsViewModel = SettingsViewModel(environment: environment)

        Task {
            await environment.notificationService.requestAuthorization()
        }
    }
}
