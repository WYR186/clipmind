import SwiftUI
import UniformTypeIdentifiers

struct LocalFilesView: View {
    @ObservedObject var viewModel: LocalFilesViewModel
    @State private var isPickingBatchFiles: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionCardView(title: "Local File") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("/path/to/video.mp4", text: $viewModel.filePathInput)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Use Sample") {
                                viewModel.useSampleFile()
                            }
                            Button(AppCopy.Buttons.inspect) {
                                viewModel.inspect()
                            }
                            .disabled(viewModel.isInspecting)
                            if viewModel.isInspecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Spacer()
                        }
                    }
                }

                SectionCardView(title: "Batch Local Files") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button("Select Files") {
                                isPickingBatchFiles = true
                            }
                            Text("\(viewModel.batchFilePaths.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        Picker("Batch Operation", selection: $viewModel.batchOperationType) {
                            Text("Transcribe").tag(BatchOperationType.transcribe)
                            Text("Summarize").tag(BatchOperationType.summarize)
                            Text("Translate").tag(BatchOperationType.translate)
                            Text("Export Audio").tag(BatchOperationType.exportAudio)
                        }

                        if !viewModel.batchFilePaths.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.batchFilePaths.prefix(4), id: \.self) { path in
                                    Text(path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if viewModel.batchFilePaths.count > 4 {
                                    Text("+\(viewModel.batchFilePaths.count - 4) more")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        HStack {
                            Button("Create & Run Batch") {
                                viewModel.createBatchFromSelectedFiles()
                            }
                            .disabled(viewModel.isCreatingBatch || viewModel.batchFilePaths.isEmpty)

                            if viewModel.isCreatingBatch {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Spacer()
                        }
                    }
                }

                if let metadata = viewModel.metadata {
                    SectionCardView(title: "File Metadata") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(metadata.title)
                                .font(.headline)
                            Text("Duration: \(metadata.durationSeconds)s")
                                .foregroundStyle(.secondary)
                            if viewModel.isAdvancedMode {
                                if let container = metadata.container {
                                    Text("Container: \(container)")
                                }
                                if let bitrateKbps = metadata.bitrateKbps {
                                    Text("Bitrate: \(bitrateKbps) kbps")
                                }
                            }
                            Text("Video Streams: \(metadata.videoOptions.map { $0.displayLabel }.joined(separator: ", "))")
                            Text("Audio Streams: \(metadata.audioOptions.map { $0.displayLabel }.joined(separator: ", "))")
                            if viewModel.isAdvancedMode, !metadata.subtitleTracks.isEmpty {
                                Text("Subtitle Streams: \(metadata.subtitleTracks.map { $0.displayLabel }.joined(separator: ", "))")
                            }
                        }
                    }
                }

                SectionCardView(title: "Transcription") {
                    VStack(alignment: .leading, spacing: 10) {
                        if viewModel.isAdvancedMode {
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
                        }

                        TextField("Output directory", text: $viewModel.outputDirectoryInput)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Enable audio preprocessing", isOn: $viewModel.preprocessingEnabled)

                        if viewModel.isAdvancedMode {
                            HStack(spacing: 16) {
                                Toggle("TXT", isOn: $viewModel.exportTXT)
                                Toggle("SRT", isOn: $viewModel.exportSRT)
                                Toggle("VTT", isOn: $viewModel.exportVTT)
                            }
                        }
                    }
                }

                SectionCardView(title: "Actions") {
                    HStack {
                        Button(AppCopy.Buttons.transcribe) {
                            viewModel.transcribe()
                        }
                        .disabled(viewModel.metadata == nil || viewModel.isProcessing)

                        Button("\(AppCopy.Buttons.transcribe) + \(AppCopy.Buttons.summarize)") {
                            viewModel.summarize()
                        }
                        .disabled(viewModel.metadata == nil || viewModel.isProcessing)

                        Spacer()
                    }
                }

                if viewModel.isAdvancedMode {
                    SectionCardView(title: "Summary Provider") {
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
                    }

                    if !viewModel.lastOperationSummary.isEmpty {
                        SectionCardView(title: "Flow Debug Summary") {
                            Text(viewModel.lastOperationSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                if !viewModel.transcriptPreview.isEmpty {
                    SectionCardView(title: "Transcript Preview") {
                        Text(viewModel.transcriptPreview)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                if !viewModel.summaryPreview.isEmpty {
                    SectionCardView(title: "Summary Preview") {
                        Text(viewModel.summaryPreview)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                if viewModel.isAdvancedMode, !viewModel.transcriptArtifacts.isEmpty {
                    SectionCardView(title: "Transcript Artifacts") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(viewModel.transcriptArtifacts, id: \.kind) { artifact in
                                Text("\(artifact.kind.rawValue.uppercased()): \(artifact.path)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                if let latestError = viewModel.latestError {
                    ErrorBannerView(error: latestError, showDiagnostics: viewModel.isAdvancedMode)
                } else if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .fileImporter(
            isPresented: $isPickingBatchFiles,
            allowedContentTypes: [.movie, .audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                viewModel.setBatchFiles(urls: urls)
            case .failure:
                break
            }
        }
    }
}
