import SwiftUI

struct VideoWorkspaceRootView: View {
    @StateObject private var appViewModel: AppViewModel

    init(appViewModel: AppViewModel) {
        self._appViewModel = StateObject(wrappedValue: appViewModel)
    }

    var body: some View {
        NavigationSplitView {
            List(AppRoute.allCases, selection: Binding(
                get: { appViewModel.router.selectedRoute },
                set: { appViewModel.router.selectedRoute = $0 }
            )) { route in
                Label(route.title, systemImage: route.icon)
                    .tag(route)
            }
            .navigationTitle("VideoWorkspace")
            .frame(minWidth: AppTheme.sidebarMinWidth)
        } detail: {
            detailView
                .frame(minWidth: AppTheme.detailMinWidth)
        }
        .sheet(isPresented: $appViewModel.isOnboardingPresented) {
            OnboardingView(isPresented: $appViewModel.isOnboardingPresented)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appViewModel.router.selectedRoute {
        case .dashboard:
            DashboardView(viewModel: appViewModel.dashboardViewModel)
        case .onlineVideo:
            OnlineVideoView(viewModel: appViewModel.onlineVideoViewModel)
        case .localFiles:
            LocalFilesView(viewModel: appViewModel.localFilesViewModel)
        case .tasks:
            TasksView(viewModel: appViewModel.tasksViewModel)
        case .history:
            HistoryView(viewModel: appViewModel.historyViewModel)
        case .settings:
            SettingsView(viewModel: appViewModel.settingsViewModel)
        }
    }
}
