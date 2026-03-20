import SwiftUI

struct PreflightSectionView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section("Preflight / Smoke Checklist") {
            PreflightStatusCard(result: viewModel.preflightResult)

            HStack {
                Button(AppCopy.Buttons.runPreflight) {
                    viewModel.runPreflight(force: true)
                }
                Spacer()
            }

            if let result = viewModel.preflightResult {
                ForEach(filteredIssues(from: result)) { issue in
                    ReadinessIssueRow(issue: issue, showDetails: viewModel.isAdvancedMode)
                }
            } else {
                Text("No preflight result yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func filteredIssues(from result: PreflightCheckResult) -> [PreflightIssue] {
        if viewModel.isAdvancedMode {
            return result.issues
        }
        return result.issues.filter { $0.severity != .ready }
    }
}

