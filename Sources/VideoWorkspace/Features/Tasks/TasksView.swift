import SwiftUI

struct TasksView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        HSplitView {
            List(selection: $viewModel.selectedTaskID) {
                ForEach(viewModel.tasks) { task in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(task.taskType.rawValue.capitalized)
                                .font(.headline)
                            Spacer()
                            TaskStatusBadge(status: task.status)
                        }
                        Text(task.source.value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(task.id)
                    .padding(.vertical, 4)
                }
            }

            Group {
                if let task = viewModel.selectedTask {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task Detail")
                            .font(.title2.bold())
                        Text("Type: \(task.taskType.rawValue)")
                        Text("Status: \(task.status.rawValue)")
                        ProgressView(value: task.progress.fractionCompleted) {
                            Text(task.progress.currentStep)
                        }
                        .padding(.top, 6)

                        if let outputPath = task.outputPath {
                            Text("Output: \(outputPath)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        if let error = task.error {
                            Text("Error: \(error.message)")
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .padding(20)
                } else {
                    VStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text("Select a task")
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
