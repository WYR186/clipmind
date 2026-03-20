import SwiftUI

struct DiagnosticsSectionView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section("Diagnostics / Logs") {
            HStack {
                Button(AppCopy.Buttons.exportDiagnosticsBundle) {
                    viewModel.exportDiagnosticsBundle()
                }
                Button(AppCopy.Buttons.copyDiagnosticsSummary) {
                    viewModel.copyDiagnosticsSummary()
                }
                Button(AppCopy.Buttons.openLogsDirectory) {
                    viewModel.openLogsDirectory()
                }
            }

            if viewModel.isAdvancedMode, !viewModel.recentDiagnosticPreview.isEmpty {
                Text(viewModel.recentDiagnosticPreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

