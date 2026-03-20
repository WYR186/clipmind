import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct VideoWorkspaceRootView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject private var router: AppRouter

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        self._router = ObservedObject(wrappedValue: appViewModel.router)
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailView
                .frame(minWidth: AppTheme.detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $appViewModel.isOnboardingPresented) {
            OnboardingView(
                isPresented: $appViewModel.isOnboardingPresented,
                onComplete: { appViewModel.completeOnboarding() }
            )
        }
        .preferredColorScheme(appViewModel.preferredColorScheme)
        .onAppear {
            #if canImport(AppKit)
            if #available(macOS 15.2, *) {
                NSApp.mainMenu?.automaticallyInsertsWritingToolsItems = false
            }
            #endif
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch router.selectedRoute {
        case .dashboard:
            DashboardView(viewModel: appViewModel.dashboardViewModel)
        case .onlineVideo:
            OnlineVideoView(viewModel: appViewModel.onlineVideoViewModel)
        case .localFiles:
            LocalFilesView(viewModel: appViewModel.localFilesViewModel)
        case .batchJobs:
            BatchJobsView(viewModel: appViewModel.batchJobsViewModel)
        case .tasks:
            TasksView(viewModel: appViewModel.tasksViewModel)
        case .history:
            HistoryView(viewModel: appViewModel.historyViewModel)
        case .settings:
            SettingsView(viewModel: appViewModel.settingsViewModel)
        }
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("VideoWorkspace")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(AppRoute.allCases) { route in
                        Button {
                            router.selectedRoute = route
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: route.icon)
                                    .frame(width: 16)
                                Text(route.title)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(route == router.selectedRoute ? Color.accentColor.opacity(0.18) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(route == router.selectedRoute ? Color.accentColor.opacity(0.45) : .clear, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }

            HStack {
                StatusBadgeView(
                    text: appViewModel.simpleModeEnabled ? "Simple" : "Advanced",
                    tint: appViewModel.simpleModeEnabled ? .blue : .green
                )
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("VideoWorkspace")
        .frame(
            minWidth: AppTheme.sidebarMinWidth,
            idealWidth: AppTheme.sidebarMinWidth + 20,
            maxWidth: AppTheme.sidebarMinWidth + 40,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(.bar)
    }
}
