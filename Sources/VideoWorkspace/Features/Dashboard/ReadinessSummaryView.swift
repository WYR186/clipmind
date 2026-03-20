import SwiftUI

struct ReadinessSummaryView: View {
    let result: SmokeChecklistResult?

    var body: some View {
        GroupBox("Release Readiness") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    StatusBadgeView(
                        text: badgeText,
                        tint: badgeColor
                    )
                    Spacer()
                    if let timestamp = result?.generatedAt {
                        Text(timestamp.shortDateTime())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(result?.summaryLine ?? "Run smoke checklist to verify machine readiness.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var badgeText: String {
        guard let result else { return "Not Run" }
        if result.isAllGreen { return "All Green" }
        if result.isAcceptable { return "Acceptable" }
        return "Needs Attention"
    }

    private var badgeColor: Color {
        guard let result else { return .secondary }
        if result.isAllGreen { return .green }
        if result.isAcceptable { return .blue }
        return .orange
    }
}

