import XCTest
@testable import VideoWorkspace

@MainActor
final class ModeGatingTests: XCTestCase {
    func testTasksViewModelReflectsSimpleAdvancedMode() async {
        let env = AppEnvironment.mock()
        var settings = AppSettings()
        settings.simpleModeEnabled = false
        await env.settingsRepository.saveSettings(settings)

        let viewModel = TasksViewModel(environment: env)
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertTrue(viewModel.isAdvancedMode)

        settings.simpleModeEnabled = true
        await env.settingsRepository.saveSettings(settings)
        NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertFalse(viewModel.isAdvancedMode)
    }

    func testSettingsResetRestoresDefaults() async {
        let env = AppEnvironment.mock()
        let viewModel = SettingsViewModel(environment: env)
        try? await Task.sleep(nanoseconds: 250_000_000)

        viewModel.settings.themeMode = .dark
        viewModel.settings.simpleModeEnabled = false
        viewModel.settings.defaults.exportDirectory = "/tmp/custom"
        viewModel.resetToDefaults()
        try? await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(viewModel.settings.themeMode, .system)
        XCTAssertTrue(viewModel.settings.simpleModeEnabled)
        XCTAssertEqual(viewModel.settings.defaults.exportDirectory, "~/Downloads/VideoWorkspace")
    }
}
