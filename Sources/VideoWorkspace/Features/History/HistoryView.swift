import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        HSplitView {
            if viewModel.entries.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: AppCopy.EmptyState.noHistoryTitle,
                    message: AppCopy.EmptyState.noHistoryMessage
                )
            } else {
                List(selection: $viewModel.selectedEntryID) {
                    ForEach(viewModel.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.source.value)
                                .font(.headline)
                                .lineLimit(1)
                            Text(entry.createdAt.shortDateTime())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(entry.id)
                    }
                }
            }

            Group {
                if let entry = viewModel.selectedEntry {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("History Detail")
                                .font(.title2.bold())
                            Text("Source: \(entry.source.value)")
                            Text("Task: \(entry.taskType.rawValue)")
                            if viewModel.isAdvancedMode {
                                Text("Last operation: \(viewModel.operationSummary(for: entry))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let taskID = entry.taskID {
                                HStack {
                                    Text("Task ID: \(taskID.uuidString)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    Button("Open Task") {
                                        viewModel.requestOpenRelatedTask()
                                    }
                                }
                            }

                            if let transcript = entry.transcript {
                                SectionCardView(title: "Transcript") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if viewModel.isAdvancedMode {
                                            if let backend = transcript.backend {
                                                Text("Backend: \(backend.rawValue)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let modelID = transcript.modelID {
                                                Text("Model: \(modelID)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Text(transcript.content)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        HStack {
                                            Button("\(AppCopy.Buttons.copy) Transcript") {
                                                viewModel.copyTranscriptToPasteboard()
                                            }
                                            Button("Translate") {
                                                viewModel.presentTranslationSheet(defaultBilingual: false)
                                            }
                                            Button("Translate Bilingual") {
                                                viewModel.presentTranslationSheet(defaultBilingual: true)
                                            }
                                            Button("Export Translation") {
                                                viewModel.presentTranslationSheet(defaultBilingual: false)
                                            }
                                        }

                                        if viewModel.isAdvancedMode, !transcript.artifacts.isEmpty {
                                            Divider()
                                            ForEach(transcript.artifacts, id: \.path) { artifact in
                                                HStack {
                                                    Text("\(artifact.kind.rawValue.uppercased()): \(artifact.path)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .textSelection(.enabled)
                                                    Spacer()
                                                    Button(AppCopy.Buttons.revealInFinder) {
                                                        viewModel.revealArtifact(path: artifact.path)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if let summary = entry.summary {
                                SectionCardView(title: "Summary") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if viewModel.isAdvancedMode {
                                            Text("Provider: \(summary.provider.rawValue)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("Model: \(summary.modelID)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if let template = summary.templateKind {
                                                Text("Template: \(template.rawValue)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Text(summary.content)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        HStack {
                                            Button("\(AppCopy.Buttons.copy) Summary") {
                                                viewModel.copySummaryToPasteboard()
                                            }
                                        }
                                    }
                                }
                            }

                            if let translation = entry.translation {
                                SectionCardView(title: "Translation") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if viewModel.isAdvancedMode {
                                            Text("Provider: \(translation.provider.rawValue)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("Model: \(translation.modelID)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("Mode: \(translation.mode.rawValue)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Text(translation.translatedText)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        if let bilingual = translation.bilingualText, !bilingual.isEmpty {
                                            Divider()
                                            Text("Bilingual")
                                                .font(.subheadline.bold())
                                            Text(bilingual)
                                                .font(.caption)
                                                .textSelection(.enabled)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }

                                        HStack {
                                            Button("\(AppCopy.Buttons.copy) Translation") {
                                                viewModel.copyTranslationToPasteboard()
                                            }
                                        }

                                        if viewModel.isAdvancedMode, !translation.artifacts.isEmpty {
                                            Divider()
                                            ForEach(translation.artifacts, id: \.path) { artifact in
                                                HStack {
                                                    Text("\(artifact.format.rawValue.uppercased()): \(artifact.path)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .textSelection(.enabled)
                                                    Spacer()
                                                    Button(AppCopy.Buttons.revealInFinder) {
                                                        viewModel.revealArtifact(path: artifact.path)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if entry.transcript != nil {
                                SectionCardView(title: "Generate Summary") {
                                    VStack(alignment: .leading, spacing: 10) {
                                        if viewModel.isAdvancedMode {
                                            Picker("Provider", selection: $viewModel.selectedProvider) {
                                                ForEach(ProviderType.allCases, id: \.self) { provider in
                                                    Text(provider.rawValue).tag(provider)
                                                }
                                            }
                                            .onChange(of: viewModel.selectedProvider) { _ in
                                                Task { await viewModel.loadModels() }
                                            }

                                            Picker("Model", selection: $viewModel.selectedModelID) {
                                                ForEach(viewModel.availableModels) { model in
                                                    Text(model.displayName).tag(model.id)
                                                }
                                            }

                                            HStack {
                                                Picker("Template", selection: $viewModel.selectedTemplateKind) {
                                                    ForEach(SummaryPromptTemplateKind.allCases, id: \.self) { kind in
                                                        Text(kind.rawValue).tag(kind)
                                                    }
                                                }
                                                Picker("Mode", selection: $viewModel.selectedMode) {
                                                    ForEach(SummaryMode.allCases, id: \.self) { mode in
                                                        Text(mode.rawValue).tag(mode)
                                                    }
                                                }
                                                Picker("Length", selection: $viewModel.selectedLength) {
                                                    ForEach(SummaryLength.allCases, id: \.self) { length in
                                                        Text(length.rawValue).tag(length)
                                                    }
                                                }
                                            }

                                            TextField("Output language", text: $viewModel.outputLanguage)
                                            TextField("Custom prompt (optional)", text: $viewModel.customPrompt)
                                        }

                                        Button("Summarize Transcript") {
                                            viewModel.summarizeSelectedEntry()
                                        }

                                        if !viewModel.statusMessage.isEmpty, viewModel.latestError == nil {
                                            Text(viewModel.statusMessage)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            if let downloadResult = entry.downloadResult {
                                SectionCardView(title: "Download Output") {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Kind: \(downloadResult.kind.rawValue)")
                                        HStack {
                                            Text(downloadResult.outputPath)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .textSelection(.enabled)
                                            Spacer()
                                            Button(AppCopy.Buttons.revealInFinder) {
                                                viewModel.revealArtifact(path: downloadResult.outputPath)
                                            }
                                        }
                                    }
                                }
                            }

                            if viewModel.isAdvancedMode, !viewModel.selectedEntryArtifacts.isEmpty {
                                SectionCardView(title: "Artifacts Index") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(viewModel.selectedEntryArtifacts) { artifact in
                                            HStack(alignment: .top) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("\(artifact.artifactType.rawValue): \(artifact.filePath)")
                                                        .font(.caption)
                                                        .textSelection(.enabled)
                                                    Text("Format: \(artifact.fileFormat)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                Button(AppCopy.Buttons.revealInFinder) {
                                                    viewModel.revealArtifact(path: artifact.filePath)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if let latestError = viewModel.latestError {
                                ErrorBannerView(error: latestError, showDiagnostics: viewModel.isAdvancedMode)
                            }

                            Spacer()
                        }
                        .padding(20)
                    }
                } else {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: AppCopy.EmptyState.noHistorySelectedTitle,
                        message: AppCopy.EmptyState.noHistorySelectedMessage
                    )
                }
            }
        }
        .sheet(item: $viewModel.translationSheetSeed) { seed in
            TranslationView(viewModel: viewModel.makeTranslationViewModel(seed: seed))
        }
    }
}
