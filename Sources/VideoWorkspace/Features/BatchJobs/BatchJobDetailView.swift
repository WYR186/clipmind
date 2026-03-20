import SwiftUI

struct BatchJobDetailView: View {
    @ObservedObject var viewModel: BatchJobsViewModel
    let batch: BatchJob
    let items: [BatchJobItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Batch Detail")
                    .font(.title2.bold())
                Text("Title: \(batch.title)")
                Text("Created: \(batch.createdAt.shortDateTime())")
                Text("Status: \(batch.status.rawValue)")
                    .foregroundStyle(statusColor(batch.status))

                ProgressView(value: batch.progress.fractionCompleted) {
                    Text(progressLine)
                }

                HStack(spacing: 8) {
                    if batch.status == .paused {
                        Button("Resume") {
                            viewModel.resumeSelectedBatch()
                        }
                    } else {
                        Button("Start") {
                            viewModel.startSelectedBatch()
                        }
                        .disabled(batch.status == .running)
                    }

                    Button("Pause") {
                        viewModel.pauseSelectedBatch()
                    }
                    .disabled(batch.status != .running)

                    Button("Retry Failed") {
                        viewModel.retryFailedItems()
                    }
                    .disabled(batch.failedCount == 0)

                    Button("Cancel Remaining") {
                        viewModel.cancelRemainingItems()
                    }
                    .disabled(batch.pendingCount == 0)

                    Button("Translate Completed") {
                        viewModel.createTranslationBatchFromCompletedItems()
                    }
                    .disabled(items.contains(where: { $0.status == .completed }) == false)

                    Button("Copy Summary") {
                        viewModel.copySelectedSummary()
                    }
                }

                if let sourceDescription = viewModel.sourceDescription(for: batch) {
                    SectionCardView(title: "Batch Source") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sourceDescription)
                            if let metadata = viewModel.playlistMetadata(for: batch) {
                                Text("Entries: \(metadata.entryCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Source URL: \(metadata.sourceURL)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                if viewModel.isAdvancedMode {
                    SectionCardView(title: "Operation Template") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Operation: \(batch.operationTemplate.operationType.rawValue)")
                            Text("Output language: \(batch.operationTemplate.outputLanguage)")
                            Text("Summary mode: \(batch.operationTemplate.summaryMode.rawValue)")
                            Text("Summary length: \(batch.operationTemplate.summaryLength.rawValue)")
                            Text("Provider / Model: \(batch.operationTemplate.provider.rawValue) / \(batch.operationTemplate.modelID)")
                            if let outputDirectory = batch.operationTemplate.outputDirectory {
                                Text("Output directory: \(outputDirectory)")
                            }
                            Text("Concurrency: \(batch.operationTemplate.maxConcurrentItems)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                SectionCardView(title: "Items (\(items.count))") {
                    if items.isEmpty {
                        EmptyStateView(
                            icon: "tray",
                            title: "No Items",
                            message: "This batch does not contain any items."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.source.value)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        StatusBadgeView(
                                            text: item.status.rawValue.capitalized,
                                            tint: itemStatusColor(item.status)
                                        )
                                    }

                                    ProgressView(value: item.progress)

                                    HStack(spacing: 8) {
                                        if item.taskID != nil {
                                            Button("Open Task") {
                                                viewModel.openTask(for: item)
                                            }
                                        }

                                        if viewModel.outputPath(for: item) != nil {
                                            Button(AppCopy.Buttons.revealInFinder) {
                                                viewModel.revealOutput(for: item)
                                            }
                                        }
                                    }
                                    .font(.caption)

                                    if let failureReason = item.failureReason {
                                        Text(failureReason)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                }

                if !viewModel.message.isEmpty {
                    Text(viewModel.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
    }

    private var progressLine: String {
        "\(batch.completedCount) completed · \(batch.failedCount) failed · \(batch.runningCount) running · \(batch.pendingCount) pending · \(batch.cancelledCount) cancelled"
    }

    private func statusColor(_ status: BatchJobStatus) -> Color {
        switch status {
        case .queued:
            return .gray
        case .running:
            return .orange
        case .paused:
            return .blue
        case .completed:
            return .green
        case .completedWithFailures:
            return .yellow
        case .failed:
            return .red
        case .cancelled:
            return .secondary
        case .interrupted:
            return .pink
        }
    }

    private func itemStatusColor(_ status: BatchJobItemStatus) -> Color {
        switch status {
        case .pending:
            return .gray
        case .running:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .blue
        case .cancelled:
            return .secondary
        case .interrupted:
            return .pink
        }
    }
}
