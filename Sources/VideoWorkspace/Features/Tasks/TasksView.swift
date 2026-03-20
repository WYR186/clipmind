import SwiftUI

struct TasksView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        HSplitView {
            if viewModel.tasks.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: AppCopy.EmptyState.noTasksTitle,
                    message: AppCopy.EmptyState.noTasksMessage
                )
            } else {
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
            }

            Group {
                if let task = viewModel.selectedTask {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task Detail")
                            .font(.title2.bold())
                        Text("Type: \(task.taskType.rawValue)")
                        Text("Status: \(task.status.rawValue)")
                        if viewModel.isAdvancedMode {
                            Text("Last operation: \(viewModel.operationSummary(for: task))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

                        if viewModel.isAdvancedMode, let failureStep = viewModel.failureStep(for: task) {
                            Text("Failure step: \(failureStep)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if viewModel.isAdvancedMode {
                            let locations = viewModel.artifactLocations(for: task)
                            if !locations.isEmpty {
                                SectionCardView(title: "Artifact Locations") {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(locations, id: \.self) { path in
                                            HStack {
                                                Text(path)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .textSelection(.enabled)
                                                Spacer()
                                                Button(AppCopy.Buttons.revealInFinder) {
                                                    viewModel.revealArtifact(path: path)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if let error = task.error {
                            if viewModel.isAdvancedMode {
                                ErrorBannerView(
                                    error: UserFacingError(
                                        title: "Task Failed",
                                        message: error.message,
                                        code: error.code,
                                        service: "TaskExecution",
                                        diagnostics: error.technicalDetails,
                                        suggestions: [.retry]
                                    ),
                                    showDiagnostics: true
                                )
                            } else {
                                Text(error.message)
                                    .foregroundStyle(.red)
                            }
                        }

                        Spacer()
                    }
                    .padding(20)
                } else {
                    EmptyStateView(
                        icon: "square.and.pencil",
                        title: AppCopy.EmptyState.noTaskSelectedTitle,
                        message: AppCopy.EmptyState.noTaskSelectedMessage
                    )
                }
            }
        }
    }
}
