import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        HSplitView {
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

            Group {
                if let entry = viewModel.selectedEntry {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("History Detail")
                                .font(.title2.bold())
                            Text("Source: \(entry.source.value)")
                            Text("Task: \(entry.taskType.rawValue)")

                            if let transcript = entry.transcript {
                                GroupBox("Transcript") {
                                    VStack(alignment: .leading, spacing: 8) {
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
                                        Text(transcript.content)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if !transcript.artifacts.isEmpty {
                                            Divider()
                                            ForEach(transcript.artifacts, id: \.kind) { artifact in
                                                Text("\(artifact.kind.rawValue.uppercased()): \(artifact.path)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            if let summary = entry.summary {
                                GroupBox("Summary") {
                                    VStack(alignment: .leading, spacing: 8) {
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
                                        Text(summary.content)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            if entry.transcript != nil {
                                GroupBox("Generate Summary") {
                                    VStack(alignment: .leading, spacing: 10) {
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

                                        Button("Summarize Transcript") {
                                            viewModel.summarizeSelectedEntry()
                                        }

                                        if !viewModel.statusMessage.isEmpty {
                                            Text(viewModel.statusMessage)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            if let downloadResult = entry.downloadResult {
                                GroupBox("Download Output") {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Kind: \(downloadResult.kind.rawValue)")
                                        Text(downloadResult.outputPath)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            Spacer()
                        }
                        .padding(20)
                    }
                } else {
                    VStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("No history selected")
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
