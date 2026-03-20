import SwiftUI

struct PreflightStatusCard: View {
    let result: PreflightCheckResult?

    var body: some View {
        let severity = result?.overallSeverity ?? .optional
        GroupBox(AppCopy.Preflight.title) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    StatusBadgeView(
                        text: severity.displayText,
                        tint: badgeTint(for: severity)
                    )
                    Spacer()
                    if let checkedAt = result?.checkedAt {
                        Text(checkedAt.shortDateTime())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(summaryText(for: result))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func summaryText(for result: PreflightCheckResult?) -> String {
        guard let result else {
            return "Run the startup checklist to verify readiness."
        }
        if result.requiresAttentionCount == 0, result.optionalCount == 0 {
            return AppCopy.Preflight.noIssues
        }
        return "\(result.requiresAttentionCount) needs attention, \(result.optionalCount) optional."
    }

    private func badgeTint(for severity: PreflightSeverity) -> Color {
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

