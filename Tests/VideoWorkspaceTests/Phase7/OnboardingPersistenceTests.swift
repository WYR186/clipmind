import XCTest
@testable import VideoWorkspace

@MainActor
final class OnboardingPersistenceTests: XCTestCase {
    func testFirstLaunchShowsOnboarding() async {
        let env = AppEnvironment.mock()
        var settings = AppSettings()
        settings.onboardingCompleted = false
        await env.settingsRepository.saveSettings(settings)

        let viewModel = AppViewModel(environment: env)
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertTrue(viewModel.isOnboardingPresented)
    }

    func testCompletingOnboardingPersistsCompletionFlag() async {
        let env = AppEnvironment.mock()
        var settings = AppSettings()
        settings.onboardingCompleted = false
        await env.settingsRepository.saveSettings(settings)

        let viewModel = AppViewModel(environment: env)
        viewModel.completeOnboarding()

        try? await Task.sleep(nanoseconds: 250_000_000)
        let latest = await env.settingsRepository.loadSettings()
        XCTAssertTrue(latest.onboardingCompleted)
    }
}
