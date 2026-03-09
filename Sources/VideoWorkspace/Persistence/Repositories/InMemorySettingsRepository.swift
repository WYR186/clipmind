import Foundation

actor InMemorySettingsRepository: SettingsRepositoryProtocol {
    private var settings = AppSettings()

    func loadSettings() async -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) async {
        self.settings = settings
    }
}
