import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            generalSection
            ReleaseReadinessSectionView(viewModel: viewModel)
            appearanceSection

            if viewModel.isAdvancedMode {
                providersSection
            } else {
                providersSimpleSection
            }

            defaultsSection

            if viewModel.isAdvancedMode {
                advancedSection
            }

            storageCacheSection
            retentionPolicySection
            DiagnosticsSectionView(viewModel: viewModel)
            AboutSectionView(viewModel: viewModel)
            SupportSectionView(viewModel: viewModel)
            actionsSection
        }
        .listStyle(.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: General

    private var generalSection: some View {
        Section("General") {
            Toggle("Simple mode", isOn: $viewModel.settings.simpleModeEnabled)
                .help("Hides advanced options. Recommended for everyday use.")
            Button("Open Onboarding") {
                viewModel.requestOnboarding()
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $viewModel.settings.themeMode) {
                ForEach(ThemeMode.allCases, id: \.self) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
                }
            }
        }
    }

    // MARK: Providers (simple)

    private var providersSimpleSection: some View {
        Section("Provider") {
            Picker("AI Provider", selection: $viewModel.selectedProvider) {
                ForEach(viewModel.providers, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .onChange(of: viewModel.selectedProvider) { _ in
                Task { await viewModel.refreshProviderStatusAndModels() }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                StatusBadgeView(
                    text: viewModel.providerStatus.rawValue.capitalized,
                    tint: viewModel.providerStatus == .connected ? .green : .orange
                )
                StatusBadgeView(
                    text: viewModel.hasStoredAPIKey ? "Key configured" : "No API key",
                    tint: viewModel.hasStoredAPIKey ? .green : .secondary
                )
            }

            SecureField("API key", text: $viewModel.apiKeyInput)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save API Key") { viewModel.saveAPIKey() }
                Button("Delete API Key") { viewModel.deleteAPIKey() }
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: Providers (advanced)

    private var providersSection: some View {
        Section("Providers") {
            Picker("Provider", selection: $viewModel.selectedProvider) {
                ForEach(viewModel.providers, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .onChange(of: viewModel.selectedProvider) { _ in
                Task { await viewModel.refreshProviderStatusAndModels() }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                StatusBadgeView(
                    text: viewModel.providerStatus.rawValue.capitalized,
                    tint: viewModel.providerStatus == .connected ? .green : .orange
                )
                StatusBadgeView(
                    text: viewModel.hasStoredAPIKey ? "Configured" : "Not Configured",
                    tint: viewModel.hasStoredAPIKey ? .green : .secondary
                )
                StatusBadgeView(
                    text: viewModel.providerCacheAvailable ? "Cache Ready" : "No Cache",
                    tint: viewModel.providerCacheAvailable ? .blue : .secondary
                )
            }

            if !viewModel.modelDescriptors.isEmpty {
                Text("Models: \(viewModel.modelDescriptors.map { $0.displayName }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SecureField("API key", text: $viewModel.apiKeyInput)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save API Key") { viewModel.saveAPIKey() }
                Button("Delete API Key") { viewModel.deleteAPIKey() }
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: Defaults

    private var defaultsSection: some View {
        Section("Defaults") {
            TextField("Default subtitle language (e.g. en)", text: $viewModel.settings.defaults.subtitleLanguage)
                .textFieldStyle(.roundedBorder)
            TextField("Default summary language (e.g. en)", text: $viewModel.settings.defaults.summaryLanguage)
                .textFieldStyle(.roundedBorder)

            Picker("Default summary provider", selection: $viewModel.settings.defaults.summaryProvider) {
                ForEach(ProviderType.allCases, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }

            TextField("Default summary model", text: $viewModel.settings.defaults.summaryModelID)
                .textFieldStyle(.roundedBorder)

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

            TextField("Preferred video quality (e.g. 720p)", text: $viewModel.settings.defaults.videoQuality)
                .textFieldStyle(.roundedBorder)
            TextField("Default export directory", text: $viewModel.settings.defaults.exportDirectory)
                .textFieldStyle(.roundedBorder)
            Toggle("Resume downloads", isOn: $viewModel.settings.defaults.resumeDownloadsEnabled)
            Picker("Overwrite policy", selection: $viewModel.settings.defaults.overwritePolicy) {
                ForEach(FileOverwritePolicy.allCases, id: \.self) { policy in
                    Text(policy.rawValue).tag(policy)
                }
            }
        }
    }

    // MARK: Advanced

    private var advancedSection: some View {
        Section("Advanced") {
            Text("Runtime mode: \(viewModel.buildInfo.runtimeMode.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.buildInfo.runtimeMode.allowsMockFallback
                ? "Debug runtime allows controlled fallback to mock adapters."
                : "Release runtime disables silent fallback to mock adapters.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Proxy mode", selection: $viewModel.settings.proxyMode) {
                ForEach(ProxyMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            TextField("Custom proxy address", text: $viewModel.settings.customProxyAddress)
                .textFieldStyle(.roundedBorder)

            Divider()

            Picker("Transcription backend", selection: $viewModel.settings.defaults.transcriptionBackend) {
                ForEach(TranscriptionBackend.allCases, id: \.self) { backend in
                    Text(backend.rawValue).tag(backend)
                }
            }
            TextField("OpenAI transcription model", text: $viewModel.settings.defaults.openAITranscriptionModel)
                .textFieldStyle(.roundedBorder)
            TextField("whisper.cpp executable path", text: $viewModel.settings.defaults.whisperExecutablePath)
                .textFieldStyle(.roundedBorder)
            TextField("Whisper model path", text: $viewModel.settings.defaults.whisperModelPath)
                .textFieldStyle(.roundedBorder)
            TextField("Transcription language hint (e.g. zh)", text: $viewModel.settings.defaults.transcriptionLanguageHint)
                .textFieldStyle(.roundedBorder)
            Toggle("Enable audio preprocessing", isOn: $viewModel.settings.defaults.transcriptionPreprocessingEnabled)

            Divider()

            Picker("Summary template", selection: $viewModel.settings.defaults.summaryTemplateKind) {
                ForEach(SummaryPromptTemplateKind.allCases, id: \.self) { kind in
                    Text(kind.rawValue).tag(kind)
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
            Toggle("Prefer structured output", isOn: $viewModel.settings.defaults.summaryStructuredOutputPreferred)

            VStack(alignment: .leading, spacing: 4) {
                Text("Transcript output formats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: AppTheme.Spacing.md) {
                    Toggle("TXT", isOn: Binding(
                        get: { viewModel.isTranscriptOutputEnabled(.txt) },
                        set: { viewModel.setTranscriptOutput(.txt, enabled: $0) }
                    ))
                    Toggle("SRT", isOn: Binding(
                        get: { viewModel.isTranscriptOutputEnabled(.srt) },
                        set: { viewModel.setTranscriptOutput(.srt, enabled: $0) }
                    ))
                    Toggle("VTT", isOn: Binding(
                        get: { viewModel.isTranscriptOutputEnabled(.vtt) },
                        set: { viewModel.setTranscriptOutput(.vtt, enabled: $0) }
                    ))
                }
            }
        }
    }

    // MARK: Storage & Cache

    private var storageCacheSection: some View {
        Section("Storage / Cache") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cache directory")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(viewModel.cacheDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Temporary files")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(viewModel.temporaryDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Logs directory")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(viewModel.logsDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack {
                Text("Cache size:")
                Text(viewModel.cacheSizeDisplay)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Button("Clear Cache") { viewModel.clearCache() }
                    .foregroundStyle(.red)
                Button(AppCopy.Buttons.openDataDirectory) { viewModel.openDataDirectory() }
                Button(AppCopy.Buttons.openExportDirectory) { viewModel.openExportDirectory() }
                Button("Open Logs") { viewModel.openLogsDirectory() }
            }
        }
    }

    // MARK: Retention policy

    private var retentionPolicySection: some View {
        Section("Artifact Retention Policy") {
            Text("Automatically remove exported files to manage disk space.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Toggle("Max age", isOn: Binding(
                    get: { viewModel.settings.retentionPolicy.maxAgeDays > 0 },
                    set: { viewModel.settings.retentionPolicy.maxAgeDays = $0 ? 30 : 0 }
                ))
                if viewModel.settings.retentionPolicy.maxAgeDays > 0 {
                    Stepper("\(viewModel.settings.retentionPolicy.maxAgeDays) days",
                            value: $viewModel.settings.retentionPolicy.maxAgeDays,
                            in: 1...365)
                }
            }

            HStack {
                Toggle("Max file count", isOn: Binding(
                    get: { viewModel.settings.retentionPolicy.maxFileCount > 0 },
                    set: { viewModel.settings.retentionPolicy.maxFileCount = $0 ? 1000 : 0 }
                ))
                if viewModel.settings.retentionPolicy.maxFileCount > 0 {
                    Stepper("\(viewModel.settings.retentionPolicy.maxFileCount) files",
                            value: $viewModel.settings.retentionPolicy.maxFileCount,
                            in: 10...100000, step: 100)
                }
            }

            HStack {
                Toggle("Max total size", isOn: Binding(
                    get: { viewModel.settings.retentionPolicy.maxTotalSizeBytes > 0 },
                    set: { viewModel.settings.retentionPolicy.maxTotalSizeBytes = $0 ? 10 * 1024 * 1024 * 1024 : 0 }
                ))
                if viewModel.settings.retentionPolicy.maxTotalSizeBytes > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: viewModel.settings.retentionPolicy.maxTotalSizeBytes, countStyle: .file))
                        .foregroundStyle(.secondary)
                    Stepper("", value: Binding(
                        get: { Int(viewModel.settings.retentionPolicy.maxTotalSizeBytes / (1024 * 1024 * 1024)) },
                        set: { viewModel.settings.retentionPolicy.maxTotalSizeBytes = Int64($0) * 1024 * 1024 * 1024 }
                    ), in: 1...500)
                }
            }

            Button("Apply Retention Policy Now") {
                viewModel.applyRetentionPolicy()
            }
            .foregroundStyle(.orange)
            .disabled(viewModel.settings.retentionPolicy.isEffectivelyDisabled)
        }
    }

    // MARK: Actions

    private var actionsSection: some View {
        Section("Actions") {
            HStack {
                Button("Save Settings") { viewModel.saveSettings() }
                    .buttonStyle(.borderedProminent)
                Button("Restore Defaults") { viewModel.resetToDefaults() }
            }

            if !viewModel.message.isEmpty {
                Text(viewModel.message)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}
