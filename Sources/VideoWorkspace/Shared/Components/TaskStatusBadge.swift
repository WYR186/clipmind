import SwiftUI

struct TaskStatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var color: Color {
        switch status {
        case .queued:
            return .gray
        case .running:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .canceled:
            return .secondary
        }
    }
}
