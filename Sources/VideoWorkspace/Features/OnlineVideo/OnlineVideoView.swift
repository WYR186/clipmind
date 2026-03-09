import SwiftUI

struct OnlineVideoView: View {
    @ObservedObject var viewModel: OnlineVideoViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Input URL") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("https://...", text: $viewModel.urlInput)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Inspect") {
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
                    .padding(.top, 4)
                }

                if let metadata = viewModel.metadata {
                    GroupBox("Inspection Result") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(metadata.title)
                                .font(.headline)
                            Text("Duration: \(metadata.durationSeconds)s")
                                .foregroundStyle(.secondary)
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
                        .padding(.top, 4)
                    }
                }

                if viewModel.canOfferTranscriptionFallback {
                    Text("No subtitle tracks found. You can offer transcription fallback in the next step.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GroupBox("Download / Export") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Output directory", text: $viewModel.outputDirectoryInput)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Download Video") {
                                viewModel.downloadVideo()
                            }
                            .disabled(viewModel.isProcessing || viewModel.metadata == nil)

                            Button("Download Audio") {
                                viewModel.downloadAudio()
                            }
                            .disabled(viewModel.isProcessing || viewModel.metadata == nil)

                            Button("Download Subtitle") {
                                viewModel.downloadSubtitle()
                            }
                            .disabled(viewModel.isProcessing || viewModel.metadata == nil)

                            Spacer()
                        }
                    }
                    .padding(.top, 4)
                }

                GroupBox("Actions") {
                    HStack {
                        Button("Copy Transcript") {
                            viewModel.copyTranscript()
                        }
                        .disabled(viewModel.isProcessing || viewModel.metadata == nil)

                        Button("Summarize") {
                            viewModel.summarize()
                        }
                        .disabled(viewModel.isProcessing || viewModel.metadata == nil)

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
                    }
                    .padding(.top, 4)
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
