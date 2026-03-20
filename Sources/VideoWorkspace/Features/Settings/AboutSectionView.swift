import SwiftUI

struct AboutSectionView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section(AppCopy.About.title) {
            labeledRow(AppCopy.About.appName, value: viewModel.buildInfo.appName)
            labeledRow(AppCopy.About.version, value: viewModel.buildInfo.version)
            labeledRow(AppCopy.About.build, value: viewModel.buildInfo.buildNumber)
            labeledRow(AppCopy.About.runtimeMode, value: viewModel.buildInfo.runtimeMode.rawValue)
            labeledRow(AppCopy.About.databasePath, value: viewModel.databasePathDisplay)
            labeledRow(AppCopy.About.logsPath, value: viewModel.logsDirectoryPath)
            labeledRow(AppCopy.About.cachePath, value: viewModel.cacheDirectoryPath)
            labeledRow(AppCopy.About.exportsPath, value: viewModel.settings.defaults.exportDirectory)

            HStack {
                Button(AppCopy.Buttons.openDataDirectory) {
                    viewModel.openDataDirectory()
                }
                Button(AppCopy.Buttons.openLogsDirectory) {
                    viewModel.openLogsDirectory()
                }
                Button(AppCopy.Buttons.openExportDirectory) {
                    viewModel.openExportDirectory()
                }
            }
        }
    }

    private func labeledRow(_ key: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

