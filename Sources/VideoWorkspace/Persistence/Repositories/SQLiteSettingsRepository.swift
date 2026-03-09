import Foundation

actor SQLiteSettingsRepository: SettingsRepositoryProtocol {
    private enum Constants {
        static let settingsKey = "app_settings_json"
    }

    private let databaseManager: DatabaseManager
    private let logger: any AppLoggerProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(databaseManager: DatabaseManager, logger: any AppLoggerProtocol) {
        self.databaseManager = databaseManager
        self.logger = logger
    }

    func loadSettings() async -> AppSettings {
        do {
            let rows = try await databaseManager.query(
                sql: SettingsSQL.select,
                bindings: [.text(Constants.settingsKey)]
            )
            guard let payload = rows.first?.text("value"), !payload.isEmpty else {
                return AppSettings()
            }

            let data = Data(payload.utf8)
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            logger.error("SettingsRepository load failed: \(error.localizedDescription)")
            return AppSettings()
        }
    }

    func saveSettings(_ settings: AppSettings) async {
        do {
            let data = try encoder.encode(settings)
            guard let payload = String(data: data, encoding: .utf8) else {
                throw PersistenceError.settingsPersistenceFailed(details: "Failed to encode settings as UTF-8")
            }

            try await databaseManager.execute(
                sql: SettingsSQL.upsert,
                bindings: [
                    .text(Constants.settingsKey),
                    .text(payload),
                    .text("json"),
                    .double(Date().timeIntervalSince1970)
                ]
            )
        } catch {
            logger.error("SettingsRepository save failed: \(error.localizedDescription)")
        }
    }
}
