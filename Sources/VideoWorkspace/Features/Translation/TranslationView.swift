import SwiftUI

struct TranslationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TranslationViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    configurationSection
                    if let result = viewModel.translationResult {
                        previewSection(result: result)
                    }
                    statusSection
                }
                .padding(AppTheme.Spacing.lg)
            }
            .frame(minWidth: 760, minHeight: 560)
            .navigationTitle("Translate Transcript")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: Configuration

    private var configurationSection: some View {
        SectionCardView(title: "Translation Configuration") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                // Language pair
                HStack(spacing: AppTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Source language")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("auto-detect", text: $viewModel.sourceLanguage)
                            .textFieldStyle(.roundedBorder)
                    }
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .padding(.top, AppTheme.Spacing.md)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target language")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. en, zh, ja", text: $viewModel.targetLanguage)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if viewModel.sourceLanguage.isEmpty {
                    Text("Source language will be auto-detected from the transcript.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Mode & style
                HStack(spacing: AppTheme.Spacing.md) {
                    Picker("Mode", selection: $viewModel.mode) {
                        ForEach(TranslationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .frame(maxWidth: 220)

                    Picker("Style", selection: $viewModel.style) {
                        ForEach(TranslationStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .frame(maxWidth: 200)
                }

                // Advanced options
                if viewModel.isAdvancedMode {
                    Divider()

                    HStack(spacing: AppTheme.Spacing.md) {
                        Picker("Provider", selection: $viewModel.selectedProvider) {
                            ForEach(ProviderType.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .onChange(of: viewModel.selectedProvider) { _ in
                            Task { await viewModel.loadModels() }
                        }
                        .frame(maxWidth: 200)

                        Picker("Model", selection: $viewModel.selectedModelID) {
                            ForEach(viewModel.availableModels) { model in
                                Text(model.displayName).tag(model.id)
                            }
                        }
                        .frame(maxWidth: 240)
                    }

                    // Output directory with browse button
                    HStack(spacing: AppTheme.Spacing.sm) {
                        TextField("Output directory (optional)", text: $viewModel.outputDirectoryInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse…") {
                            viewModel.browseOutputDirectory()
                        }
                    }
                }

                Divider()

                // Output toggles
                HStack(spacing: AppTheme.Spacing.md) {
                    Toggle("Bilingual output", isOn: $viewModel.bilingualOutputEnabled)
                    Toggle("Preserve timestamps", isOn: $viewModel.preserveTimestamps)
                    Toggle("Preserve terminology", isOn: $viewModel.preserveTerminology)
                }

                if viewModel.isAdvancedMode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export formats")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: AppTheme.Spacing.md) {
                            Toggle("TXT", isOn: $viewModel.exportTXT)
                            Toggle("SRT", isOn: $viewModel.exportSRT)
                            Toggle("VTT", isOn: $viewModel.exportVTT)
                            Toggle("Markdown", isOn: $viewModel.exportMarkdown)
                        }
                        Text(viewModel.exportFormatSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Action buttons
                HStack {
                    Button("Translate") {
                        viewModel.translate()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRunning || viewModel.targetLanguage.isEmpty)

                    if viewModel.isRunning {
                        Button("Cancel") {
                            viewModel.cancelTranslation()
                        }
                        .foregroundStyle(.red)
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: Preview

    private func previewSection(result: TranslationResult) -> some View {
        SectionCardView(title: "Translation Preview") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                TranslationPreviewView(
                    result: result,
                    showAdvanced: viewModel.isAdvancedMode,
                    onRevealArtifact: { viewModel.revealArtifact(path: $0) }
                )

                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Copy Translation") {
                        viewModel.copyTranslatedText()
                    }
                    if result.bilingualText != nil {
                        Button("Copy Bilingual") {
                            viewModel.copyBilingualText()
                        }
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Status

    @ViewBuilder
    private var statusSection: some View {
        if let error = viewModel.latestError {
            ErrorBannerView(error: error, showDiagnostics: viewModel.isAdvancedMode)
        } else if !viewModel.isRunning, !viewModel.statusMessage.isEmpty {
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
