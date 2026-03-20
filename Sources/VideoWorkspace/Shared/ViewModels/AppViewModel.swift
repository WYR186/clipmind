import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    let environment: AppEnvironment
    let router: AppRouter

    @Published var isOnboardingPresented: Bool = false
    @Published private(set) var activeThemeMode: ThemeMode = .system
    @Published private(set) var simpleModeEnabled: Bool = true

    let dashboardViewModel: DashboardViewModel
    let onlineVideoViewModel: OnlineVideoViewModel
    let localFilesViewModel: LocalFilesViewModel
    let batchJobsViewModel: BatchJobsViewModel
    let tasksViewModel: TasksViewModel
    let historyViewModel: HistoryViewModel
    let settingsViewModel: SettingsViewModel
    private var observerTokens: [NSObjectProtocol] = []

    init(environment: AppEnvironment) {
        self.environment = environment
        self.router = AppRouter()

        dashboardViewModel = DashboardViewModel(environment: environment)
        onlineVideoViewModel = OnlineVideoViewModel(environment: environment)
        localFilesViewModel = LocalFilesViewModel(environment: environment)
        batchJobsViewModel = BatchJobsViewModel(environment: environment)
        tasksViewModel = TasksViewModel(environment: environment)
        historyViewModel = HistoryViewModel(environment: environment)
        settingsViewModel = SettingsViewModel(environment: environment)

        registerObservers()

        Task {
            await refreshAppPresentationSettings()
            await environment.notificationService.requestAuthorization()
            _ = await environment.preflightCheckService.runChecks(force: false)
            _ = await environment.smokeChecklistService.runChecklist(force: false)
        }
    }

    deinit {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch activeThemeMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func completeOnboarding() {
        Task {
            var settings = await environment.settingsRepository.loadSettings()
            settings.onboardingCompleted = true
            await environment.settingsRepository.saveSettings(settings)
            NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
            isOnboardingPresented = false
        }
    }

    private func registerObservers() {
        let settingsToken = NotificationCenter.default.addObserver(
            forName: .appSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAppPresentationSettings()
            }
        }
        observerTokens.append(settingsToken)

        let onboardingToken = NotificationCenter.default.addObserver(
            forName: .appOnboardingRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isOnboardingPresented = true
            }
        }
        observerTokens.append(onboardingToken)

        let openTaskToken = NotificationCenter.default.addObserver(
            forName: .appOpenTaskRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let taskID = notification.userInfo?["taskID"] as? UUID else {
                    return
                }
                self.router.selectedRoute = .tasks
                self.tasksViewModel.selectTask(taskID)
            }
        }
        observerTokens.append(openTaskToken)

        let openBatchToken = NotificationCenter.default.addObserver(
            forName: .appOpenBatchRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let batchID = notification.userInfo?["batchID"] as? UUID else {
                    return
                }
                self.router.selectedRoute = .batchJobs
                self.batchJobsViewModel.selectBatch(batchID)
            }
        }
        observerTokens.append(openBatchToken)
    }

    private func refreshAppPresentationSettings() async {
        let settings = await environment.settingsRepository.loadSettings()
        activeThemeMode = settings.themeMode
        simpleModeEnabled = settings.simpleModeEnabled
        isOnboardingPresented = !settings.onboardingCompleted
    }
}
