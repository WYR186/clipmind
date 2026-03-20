import SwiftUI

struct BatchJobsView: View {
    @ObservedObject var viewModel: BatchJobsViewModel

    var body: some View {
        HSplitView {
            if viewModel.batches.isEmpty {
                EmptyStateView(
                    icon: "square.stack.3d.down.right",
                    title: "No Batch Jobs",
                    message: "Create a batch from Online Video or Local Files to run multiple tasks in one queue."
                )
            } else {
                List(selection: $viewModel.selectedBatchID) {
                    ForEach(viewModel.batches) { batch in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(batch.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Spacer()
                                StatusBadgeView(
                                    text: displayStatusText(batch.status),
                                    tint: statusColor(batch.status)
                                )
                            }

                            ProgressView(value: batch.progress.fractionCompleted)

                            Text("\(batch.completedCount)/\(batch.totalCount) complete · \(batch.failedCount) failed · \(batch.pendingCount) pending")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let sourceDescription = viewModel.sourceDescription(for: batch) {
                                Text(sourceDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .tag(batch.id)
                        .padding(.vertical, 4)
                    }
                }
            }

            Group {
                if let selectedBatch = viewModel.selectedBatch {
                    BatchJobDetailView(
                        viewModel: viewModel,
                        batch: selectedBatch,
                        items: viewModel.selectedBatchItems
                    )
                } else {
                    EmptyStateView(
                        icon: "square.and.pencil",
                        title: "Select a Batch",
                        message: "Choose a batch to view item-level status and quick actions."
                    )
                }
            }
        }
    }

    private func displayStatusText(_ status: BatchJobStatus) -> String {
        switch status {
        case .completedWithFailures:
            return "Partial"
        default:
            return status.rawValue.capitalized
        }
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
}
