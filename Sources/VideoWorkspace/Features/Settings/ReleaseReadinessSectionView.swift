import SwiftUI

struct ReleaseReadinessSectionView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section("Smoke Test Checklist") {
            ReadinessSummaryView(result: viewModel.smokeChecklistResult)

            HStack {
                Button(AppCopy.Buttons.rerunChecklist) {
                    viewModel.runSmokeChecklist(force: true)
                }
                Button(AppCopy.Buttons.copyChecklistSummary) {
                    viewModel.copySmokeChecklistSummary()
                }
                Button(AppCopy.Buttons.exportChecklistResult) {
                    viewModel.exportSmokeChecklistResult()
                }
            }

            if let result = viewModel.smokeChecklistResult {
                ForEach(filteredItems(result.items)) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            StatusBadgeView(
                                text: item.status.displayText,
                                tint: tint(for: item.status)
                            )
                        }
                        Text(item.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if viewModel.isAdvancedMode, let details = item.details, !details.isEmpty {
                            Text(details)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func filteredItems(_ items: [SmokeChecklistItem]) -> [SmokeChecklistItem] {
        if viewModel.isAdvancedMode {
            return items
        }
        return items.filter { $0.status != .pass }
    }

    private func tint(for status: SmokeChecklistItemStatus) -> Color {
        switch status {
        case .pass:
            return .green
        case .warning:
            return .blue
        case .fail:
            return .orange
        }
    }
}

