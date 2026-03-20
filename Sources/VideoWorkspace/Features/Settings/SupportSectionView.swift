import SwiftUI

struct SupportSectionView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section(AppCopy.Support.title) {
            if let summary = viewModel.supportSummary {
                Text(summary.text)
                    .font(.caption)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            } else {
                Text("Support summary unavailable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(AppCopy.Buttons.copySupportSummary) {
                    viewModel.copySupportSummary()
                }
                Button(AppCopy.Buttons.exportDiagnosticsBundle) {
                    viewModel.exportDiagnosticsBundle()
                }
                Button(AppCopy.Buttons.openLogsDirectory) {
                    viewModel.openLogsDirectory()
                }
                Button(AppCopy.Buttons.openExportDirectory) {
                    viewModel.openExportDirectory()
                }
                Button(AppCopy.Buttons.openDataDirectory) {
                    viewModel.openDataDirectory()
                }
            }
        }
    }
}

