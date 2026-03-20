import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@main
struct VideoWorkspaceApp: App {
    @StateObject private var appViewModel = AppViewModel(environment: .defaultEnvironment())

    init() {
        #if canImport(AppKit)
        UserDefaults.standard.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextCompletionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextReplacementEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticPeriodSubstitutionEnabled")
        if #available(macOS 15.2, *) {
            NSApp.mainMenu?.automaticallyInsertsWritingToolsItems = false
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            VideoWorkspaceRootView(appViewModel: appViewModel)
                .frame(minWidth: 1100, minHeight: 720)
                .onAppear {
                    #if canImport(AppKit)
                    // Bring the app window to the front automatically after launch,
                    // even when built and run from Xcode (which keeps itself as key app).
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    #endif
                }
        }
    }
}
