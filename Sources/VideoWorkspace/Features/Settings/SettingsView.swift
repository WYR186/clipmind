import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Defaults") {
                TextField("Default subtitle language", text: $viewModel.settings.defaults.subtitleLanguage)
                TextField("Default summary language", text: $viewModel.settings.defaults.summaryLanguage)
                Picker("Default summary provider", selection: $viewModel.settings.defaults.summaryProvider) {
                    ForEach(ProviderType.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                TextField("Default summary model", text: $viewModel.settings.defaults.summaryModelID)
                Picker("Default summary template", selection: $viewModel.settings.defaults.summaryTemplateKind) {
                    ForEach(SummaryPromptTemplateKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }

                Picker("Default summary mode", selection: $viewModel.settings.defaults.summaryMode) {
                    ForEach(SummaryMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Picker("Default summary length", selection: $viewModel.settings.defaults.summaryLength) {
                    ForEach(SummaryLength.allCases, id: \.self) { length in
                        Text(length.rawValue).tag(length)
                    }
                }
                Picker("Summary output format", selection: $viewModel.settings.defaults.summaryOutputFormat) {
                    ForEach(SummaryOutputFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                Picker("Summary chunking strategy", selection: $viewModel.settings.defaults.summaryChunkingStrategy) {
                    ForEach(SummaryChunkingStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                Toggle("Prefer structured summary output", isOn: $viewModel.settings.defaults.summaryStructuredOutputPreferred)

                TextField("Default video quality", text: $viewModel.settings.defaults.videoQuality)
                TextField("Default export directory", text: $viewModel.settings.defaults.exportDirectory)
                Toggle("Resume downloads", isOn: $viewModel.settings.defaults.resumeDownloadsEnabled)
                Picker("Overwrite policy", selection: $viewModel.settings.defaults.overwritePolicy) {
                    ForEach(FileOverwritePolicy.allCases, id: \.self) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }

                Divider()
                Picker("Default transcription backend", selection: $viewModel.settings.defaults.transcriptionBackend) {
                    ForEach(TranscriptionBackend.allCases, id: \.self) { backend in
                        Text(backend.rawValue).tag(backend)
                    }
                }
                TextField("OpenAI transcription model", text: $viewModel.settings.defaults.openAITranscriptionModel)
                TextField("whisper.cpp executable path", text: $viewModel.settings.defaults.whisperExecutablePath)
                TextField("Whisper model path", text: $viewModel.settings.defaults.whisperModelPath)
                TextField("Default transcription language", text: $viewModel.settings.defaults.transcriptionLanguageHint)
                Toggle("Enable transcription preprocessing", isOn: $viewModel.settings.defaults.transcriptionPreprocessingEnabled)

                HStack(spacing: 14) {
                    Toggle(
                        "TXT",
                        isOn: Binding(
                            get: { viewModel.isTranscriptOutputEnabled(.txt) },
                            set: { viewModel.setTranscriptOutput(.txt, enabled: $0) }
                        )
                    )
                    Toggle(
                        "SRT",
                        isOn: Binding(
                            get: { viewModel.isTranscriptOutputEnabled(.srt) },
                            set: { viewModel.setTranscriptOutput(.srt, enabled: $0) }
                        )
                    )
                    Toggle(
                        "VTT",
                        isOn: Binding(
                            get: { viewModel.isTranscriptOutputEnabled(.vtt) },
                            set: { viewModel.setTranscriptOutput(.vtt, enabled: $0) }
                        )
                    )
                }
            }

            Section("App Behavior") {
                Picker("Theme", selection: $viewModel.settings.themeMode) {
                    ForEach(ThemeMode.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }

                Picker("Proxy mode", selection: $viewModel.settings.proxyMode) {
                    ForEach(ProxyMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                TextField("Custom proxy", text: $viewModel.settings.customProxyAddress)
                Toggle("Simple mode", isOn: $viewModel.settings.simpleModeEnabled)
            }

            Section("Provider") {
                Picker("Provider", selection: $viewModel.selectedProvider) {
                    ForEach(viewModel.providers, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .onChange(of: viewModel.selectedProvider) { _ in
                    Task { await viewModel.refreshProviderStatusAndModels() }
                }

                Text("Status: \(viewModel.providerStatus.rawValue)")
                    .foregroundStyle(.secondary)

                if !viewModel.modelDescriptors.isEmpty {
                    Text("Models: \(viewModel.modelDescriptors.map { $0.displayName }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("API key", text: $viewModel.apiKeyInput)
                Button("Save API Key") {
                    viewModel.saveAPIKey()
                }
            }

            Section {
                Button("Save Settings") {
                    viewModel.saveSettings()
                }
                if !viewModel.message.isEmpty {
                    Text(viewModel.message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }
}
