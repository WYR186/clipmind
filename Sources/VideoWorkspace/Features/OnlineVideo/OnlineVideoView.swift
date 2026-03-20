import SwiftUI

struct OnlineVideoView: View {
    @ObservedObject var viewModel: OnlineVideoViewModel
    @State private var localURLInput: String = ""
    @State private var localBatchURLsInput: String = ""
    @State private var localOutputDirectoryInput: String = ""
    @State private var didSeedLocalInputs: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionCardView(title: "Input URL") {
                    VStack(alignment: .leading, spacing: 10) {
                        MacTextInputField(placeholder: "https://...", text: $localURLInput)

                        HStack {
                            Button(AppCopy.Buttons.inspect) {
                                syncLocalInputsToViewModel()
                                viewModel.inspect()
                            }
                            .disabled(viewModel.isInspecting)

                            Button(AppCopy.Buttons.expandPlaylist) {
                                syncLocalInputsToViewModel()
                                viewModel.expandPlaylistFromInputURL()
                            }
                            .disabled(viewModel.isExpandingPlaylist || !isLikelyPlaylistInput)

                            if viewModel.isInspecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }

                            if viewModel.isExpandingPlaylist {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }

                            Spacer()
                        }
                    }
                }

                SectionCardView(title: "Batch URLs") {
                    VStack(alignment: .leading, spacing: 10) {
                        MacMultilineTextInputField(text: $localBatchURLsInput)
                            .frame(minHeight: 130, idealHeight: 150, maxHeight: 260)
                            .padding(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                            )

                        Picker("Batch Operation", selection: $viewModel.batchOperationType) {
                            Text("Export Audio").tag(BatchOperationType.exportAudio)
                            Text("Export Video").tag(BatchOperationType.exportVideo)
                            Text("Export Subtitle").tag(BatchOperationType.exportSubtitle)
                            Text("Copy Transcript").tag(BatchOperationType.copyTranscript)
                            Text("Summarize").tag(BatchOperationType.summarize)
                            Text("Translate").tag(BatchOperationType.translate)
                        }

                        HStack {
                            Button("Create & Run Batch") {
                                syncLocalInputsToViewModel()
                                viewModel.createBatchFromURLs()
                            }
                            .disabled(viewModel.isCreatingBatch)

                            if viewModel.isCreatingBatch {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Spacer()
                        }
                    }
                }

                if let playlistMetadata = viewModel.playlistMetadata {
                    PlaylistExpansionView(
                        metadata: playlistMetadata,
                        items: $viewModel.expandedPlaylistItems,
                        skippedItems: viewModel.playlistSkippedItems,
                        isCreatingBatch: viewModel.isCreatingBatch,
                        onSelectAll: { viewModel.selectAllExpandedPlaylistItems() },
                        onDeselectAll: { viewModel.deselectAllExpandedPlaylistItems() },
                        onCreateBatch: { viewModel.createBatchFromExpandedPlaylist() },
                        onClear: { viewModel.clearPlaylistExpansionPreview() }
                    )
                }

                if let metadata = viewModel.metadata {
                    SectionCardView(title: "Inspection Result") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(metadata.title)
                                .font(.headline)
                            Text("Duration: \(metadata.durationSeconds)s")
                                .foregroundStyle(.secondary)

                            if viewModel.isAdvancedMode {
                                if let platform = metadata.platform {
                                    Text("Platform: \(platform)")
                                        .foregroundStyle(.secondary)
                                }
                                if let webpageURL = metadata.webpageURL {
                                    Text("Webpage: \(webpageURL)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                if let thumbnail = metadata.thumbnailURL {
                                    Text("Thumbnail: \(thumbnail)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }

                            Text("Video Format")
                                .font(.subheadline.bold())
                            Picker("Video", selection: $viewModel.selectedVideoFormatID) {
                                ForEach(metadata.videoOptions) { option in
                                    Text(option.displayLabel)
                                        .tag(option.formatID ?? "")
                                }
                            }

                            Text("Audio Format")
                                .font(.subheadline.bold())
                            Picker("Audio", selection: $viewModel.selectedAudioFormatID) {
                                ForEach(metadata.audioOptions) { option in
                                    Text(option.displayLabel)
                                        .tag(option.formatID ?? "")
                                }
                            }

                            Text("Subtitle Tracks")
                                .font(.subheadline.bold())
                            Picker("Subtitle", selection: $viewModel.selectedSubtitleTrackID) {
                                ForEach(metadata.subtitleTracks) { track in
                                    Text(track.displayLabel)
                                        .tag(Optional(track.id))
                                }
                            }

                            Picker("Subtitle format", selection: $viewModel.preferredSubtitleFormat) {
                                ForEach(SubtitleExportFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue.uppercased()).tag(format)
                                }
                            }
                        }
                    }
                }

                if viewModel.canOfferTranscriptionFallback {
                    Text("No subtitle tracks found. You can use transcription fallback in the next step.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SectionCardView(title: "Download / Export") {
                    VStack(alignment: .leading, spacing: 10) {
                        MacTextInputField(placeholder: "Output directory", text: $localOutputDirectoryInput)

                        HStack {
                            Button("\(AppCopy.Buttons.export) Video") {
                                syncLocalInputsToViewModel()
                                viewModel.downloadVideo()
                            }
                            .disabled(viewModel.isProcessing || viewModel.metadata == nil)

                            Button("\(AppCopy.Buttons.export) Audio") {
                                syncLocalInputsToViewModel()
                                viewModel.downloadAudio()
                            }
                            .disabled(viewModel.isProcessing || viewModel.metadata == nil)

                            Button("\(AppCopy.Buttons.export) Subtitle") {
                                syncLocalInputsToViewModel()
                                viewModel.downloadSubtitle()
                            }
                            .disabled(viewModel.isProcessing || viewModel.metadata == nil)

                            Spacer()
                        }
                    }
                }

                SectionCardView(title: "Actions") {
                    HStack {
                        Button("\(AppCopy.Buttons.copy) Transcript") {
                            viewModel.copyTranscript()
                        }
                        .disabled(viewModel.isProcessing || viewModel.metadata == nil)

                        Button(AppCopy.Buttons.summarize) {
                            viewModel.summarize()
                        }
                        .disabled(viewModel.isProcessing || viewModel.metadata == nil)

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

                if let latestError = viewModel.latestError {
                    ErrorBannerView(error: latestError, showDiagnostics: viewModel.isAdvancedMode)
                } else if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .onAppear {
            seedLocalInputsIfNeeded()
        }
    }

    private var isLikelyPlaylistInput: Bool {
        viewModel.isLikelyPlaylistURL(localURLInput)
    }

    private func seedLocalInputsIfNeeded() {
        guard !didSeedLocalInputs else { return }
        localURLInput = viewModel.urlInput
        localBatchURLsInput = viewModel.batchURLsInput
        localOutputDirectoryInput = viewModel.outputDirectoryInput
        didSeedLocalInputs = true
    }

    private func syncLocalInputsToViewModel() {
        viewModel.urlInput = localURLInput
        viewModel.batchURLsInput = localBatchURLsInput
        viewModel.outputDirectoryInput = localOutputDirectoryInput
    }
}
