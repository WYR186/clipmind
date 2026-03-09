import SwiftUI

struct LocalFilesView: View {
    @ObservedObject var viewModel: LocalFilesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Local File") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("/path/to/video.mp4", text: $viewModel.filePathInput)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Use Sample") {
                                viewModel.useSampleFile()
                            }
                            Button("Inspect") {
                                viewModel.inspect()
                            }
                            .disabled(viewModel.isInspecting)
                            Spacer()
                        }
                    }
                    .padding(.top, 4)
                }

                if let metadata = viewModel.metadata {
                    GroupBox("File Metadata") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(metadata.title)
                                .font(.headline)
                            Text("Duration: \(metadata.durationSeconds)s")
                                .foregroundStyle(.secondary)
                            if let container = metadata.container {
                                Text("Container: \(container)")
                            }
                            if let bitrateKbps = metadata.bitrateKbps {
                                Text("Bitrate: \(bitrateKbps) kbps")
                            }
                            Text("Video Streams: \(metadata.videoOptions.map { $0.displayLabel }.joined(separator: ", "))")
                            Text("Audio Streams: \(metadata.audioOptions.map { $0.displayLabel }.joined(separator: ", "))")
                            if !metadata.subtitleTracks.isEmpty {
                                Text("Subtitle Streams: \(metadata.subtitleTracks.map { $0.displayLabel }.joined(separator: ", "))")
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                GroupBox("Transcription") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Backend", selection: $viewModel.selectedTranscriptionBackend) {
                            ForEach(TranscriptionBackend.allCases, id: \.self) { backend in
                                Text(backend.rawValue).tag(backend)
                            }
                        }

                        if viewModel.selectedTranscriptionBackend == .openAI {
                            TextField("OpenAI model", text: $viewModel.openAIModelID)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("whisper.cpp executable path (optional)", text: $viewModel.whisperExecutablePath)
                                .textFieldStyle(.roundedBorder)
                            TextField("Whisper model path", text: $viewModel.whisperModelPath)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            TextField("Language hint (optional)", text: $viewModel.transcriptionLanguageHint)
                                .textFieldStyle(.roundedBorder)
                            TextField("Temperature", text: $viewModel.transcriptionTemperatureInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }

                        TextField("Prompt hint (optional)", text: $viewModel.transcriptionPromptHint)
                            .textFieldStyle(.roundedBorder)

                        TextField("Output directory", text: $viewModel.outputDirectoryInput)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Enable audio preprocessing", isOn: $viewModel.preprocessingEnabled)

                        HStack(spacing: 16) {
                            Toggle("TXT", isOn: $viewModel.exportTXT)
                            Toggle("SRT", isOn: $viewModel.exportSRT)
                            Toggle("VTT", isOn: $viewModel.exportVTT)
                        }
                    }
                    .padding(.top, 4)
                }

                GroupBox("Actions") {
                    HStack {
                        Button("Transcribe") {
                            viewModel.transcribe()
                        }
                        .disabled(viewModel.metadata == nil || viewModel.isProcessing)

                        Button("Transcribe + Summarize") {
                            viewModel.summarize()
                        }
                        .disabled(viewModel.metadata == nil || viewModel.isProcessing)

                        Spacer()
                    }
                    .padding(.top, 4)
                }

                GroupBox("Summary Provider") {
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

                        Picker("Template", selection: $viewModel.selectedSummaryTemplateKind) {
                            ForEach(SummaryPromptTemplateKind.allCases, id: \.self) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }

                        HStack {
                            Picker("Mode", selection: $viewModel.selectedSummaryMode) {
                                ForEach(SummaryMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            Picker("Length", selection: $viewModel.selectedSummaryLength) {
                                ForEach(SummaryLength.allCases, id: \.self) { length in
                                    Text(length.rawValue).tag(length)
                                }
                            }
                        }

                        HStack {
                            TextField("Output language", text: $viewModel.summaryOutputLanguage)
                                .textFieldStyle(.roundedBorder)
                            Picker("Output format", selection: $viewModel.summaryOutputFormat) {
                                ForEach(SummaryOutputFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .frame(width: 170)
                        }

                        Picker("Chunking", selection: $viewModel.summaryChunkingStrategy) {
                            ForEach(SummaryChunkingStrategy.allCases, id: \.self) { strategy in
                                Text(strategy.rawValue).tag(strategy)
                            }
                        }
                        Toggle("Prefer structured output", isOn: $viewModel.summaryStructuredOutputPreferred)
                        TextField("Custom prompt override (optional)", text: $viewModel.customSummaryPrompt)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.top, 4)
                }

                if !viewModel.transcriptPreview.isEmpty {
                    GroupBox("Transcript Preview") {
                        Text(viewModel.transcriptPreview)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                if !viewModel.summaryPreview.isEmpty {
                    GroupBox("Summary Preview") {
                        Text(viewModel.summaryPreview)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                if !viewModel.transcriptArtifacts.isEmpty {
                    GroupBox("Transcript Artifacts") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(viewModel.transcriptArtifacts, id: \.kind) { artifact in
                                Text("\(artifact.kind.rawValue.uppercased()): \(artifact.path)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
    }
}
