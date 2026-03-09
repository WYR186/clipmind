import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings = AppSettings()
    @Published var providers: [ProviderType] = []
    @Published var selectedProvider: ProviderType = .openAI
    @Published var modelDescriptors: [ModelDescriptor] = []
    @Published var providerStatus: ProviderConnectionStatus = .unknown
    @Published var apiKeyInput: String = ""
    @Published var message: String = ""

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        Task {
            await load()
        }
    }

    func load() async {
        settings = await environment.settingsRepository.loadSettings()
        providers = await environment.providerRegistry.availableProviders()
        selectedProvider = providers.first ?? .openAI
        await refreshProviderStatusAndModels()
    }

    func refreshProviderStatusAndModels() async {
        providerStatus = await environment.providerRegistry.connectionStatus(for: selectedProvider)
        modelDescriptors = (try? await environment.modelDiscoveryService.discoverModels(for: selectedProvider)) ?? []
    }

    func saveSettings() {
        Task {
            await environment.settingsRepository.saveSettings(settings)
            message = "Settings saved"
        }
    }

    func saveAPIKey() {
        Task {
            do {
                try await environment.secretsStore.setSecret(apiKeyInput, for: selectedProvider.rawValue)
                message = "API key saved (mock store)"
                apiKeyInput = ""
            } catch {
                message = "Failed to save API key"
            }
        }
    }

    func isTranscriptOutputEnabled(_ kind: TranscriptOutputKind) -> Bool {
        settings.defaults.transcriptOutputFormats.contains(kind)
    }

    func setTranscriptOutput(_ kind: TranscriptOutputKind, enabled: Bool) {
        var formats = Set(settings.defaults.transcriptOutputFormats)
        if enabled {
            formats.insert(kind)
        } else {
            formats.remove(kind)
        }

        if formats.isEmpty {
            formats.insert(.txt)
        }

        settings.defaults.transcriptOutputFormats = Array(formats).sorted { $0.rawValue < $1.rawValue }
    }
}
