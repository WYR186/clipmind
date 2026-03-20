import Foundation

struct DiagnosticsExportService: DiagnosticsExportServiceProtocol {
    let logger: any AppLoggerProtocol
    let diagnosticsDirectory: URL

    init(
        logger: any AppLoggerProtocol,
        diagnosticsDirectory: URL
    ) {
        self.logger = logger
        self.diagnosticsDirectory = diagnosticsDirectory
    }

    func exportDiagnostics(
        settings: AppSettings,
        tasks: [TaskItem],
        historyEntries: [HistoryEntry]
    ) async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: diagnosticsDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let exportDirectory = diagnosticsDirectory.appendingPathComponent("diagnostics-\(timestamp)", isDirectory: true)
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let summaryURL = exportDirectory.appendingPathComponent("summary.json")
        let summary = DiagnosticsSummary(
            generatedAt: Date(),
            settings: settings,
            taskCount: tasks.count,
            historyCount: historyEntries.count,
            failedTaskCount: tasks.filter { $0.status == .failed }.count,
            recentErrors: Array(tasks.compactMap { $0.error?.message }.suffix(10))
        )
        let summaryData = try JSONEncoder().encode(summary)
        try summaryData.write(to: summaryURL)

        let recentLogURL = exportDirectory.appendingPathComponent("recent.log")
        let recentLines = logger.recentEntries(limit: 400).joined(separator: "\n")
        try recentLines.data(using: .utf8)?.write(to: recentLogURL)

        if let logFile = logger.logFileURL(), fileManager.fileExists(atPath: logFile.path) {
            let destination = exportDirectory.appendingPathComponent(logFile.lastPathComponent)
            try? fileManager.copyItem(at: logFile, to: destination)
        }

        return exportDirectory
    }
}

private struct DiagnosticsSummary: Codable {
    let generatedAt: Date
    let settings: AppSettings
    let taskCount: Int
    let historyCount: Int
    let failedTaskCount: Int
    let recentErrors: [String]
}
