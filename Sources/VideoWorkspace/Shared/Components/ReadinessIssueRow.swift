import SwiftUI

struct ReadinessIssueRow: View {
    let issue: PreflightIssue
    let showDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(issue.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadgeView(text: issue.severity.displayText, tint: tint(for: issue.severity))
            }

            Text(issue.message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !issue.suggestions.isEmpty {
                Text(issue.suggestions.map(\.message).joined(separator: " • "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if showDetails, let details = issue.details, !details.isEmpty {
                Text(details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func tint(for severity: PreflightSeverity) -> Color {
        switch severity {
        case .ready:
            return .green
        case .needsAttention:
            return .orange
        case .optional:
            return .blue
        }
    }
}

