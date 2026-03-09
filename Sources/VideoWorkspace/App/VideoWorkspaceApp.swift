import SwiftUI

@main
struct VideoWorkspaceApp: App {
    var body: some Scene {
        WindowGroup {
            VideoWorkspaceRootView(appViewModel: AppViewModel(environment: .mock()))
                .frame(minWidth: 1100, minHeight: 720)
        }
    }
}
