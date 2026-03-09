import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("VideoWorkspace")
                .font(.largeTitle.bold())

            HStack(spacing: 14) {
                metricCard(title: "Completed", value: "\(viewModel.completedCount)", tint: .green)
                metricCard(title: "Failed", value: "\(viewModel.failedCount)", tint: .red)
                metricCard(title: "History", value: "\(viewModel.historyCount)", tint: .blue)
            }

            GroupBox("Recent Tasks") {
                if viewModel.recentTasks.isEmpty {
                    Text("No tasks yet")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.recentTasks) { task in
                            HStack {
                                Text(task.taskType.rawValue.capitalized)
                                Spacer()
                                TaskStatusBadge(status: task.status)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func metricCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
