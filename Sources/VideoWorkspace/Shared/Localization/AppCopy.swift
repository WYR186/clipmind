import Foundation

enum AppCopy {
    enum Buttons {
        static let runPreflight = "Run Smoke Checklist"
        static let rerunChecklist = "Rerun Checklist"
        static let copyChecklistSummary = "Copy Checklist Summary"
        static let exportChecklistResult = "Export Checklist Result"
        static let exportDiagnosticsBundle = "Export Diagnostics Bundle"
        static let copyDiagnosticsSummary = "Copy Diagnostics Summary"
        static let copySupportSummary = "Copy Support Summary"
        static let openDataDirectory = "Open Data Directory"
        static let openLogsDirectory = "Open Logs Directory"
        static let openExportDirectory = "Open Export Directory"
        static let inspect = "Inspect"
        static let expandPlaylist = "Expand Playlist"
        static let createPlaylistBatch = "Create Batch from Selection"
        static let selectAll = "Select All"
        static let deselectAll = "Deselect All"
        static let export = "Export"
        static let transcribe = "Transcribe"
        static let summarize = "Summarize"
        static let retry = "Retry"
        static let revealInFinder = "Reveal in Finder"
        static let copy = "Copy"
    }

    enum EmptyState {
        static let noTasksTitle = "No Tasks Yet"
        static let noTasksMessage = "Run inspection, download, transcription, or summary tasks to see progress here."
        static let noTaskSelectedTitle = "Select a Task"
        static let noTaskSelectedMessage = "Choose a task from the list to inspect progress and outputs."
        static let noHistoryTitle = "No History Yet"
        static let noHistoryMessage = "Completed tasks with outputs will appear here."
        static let noHistorySelectedTitle = "No History Selected"
        static let noHistorySelectedMessage = "Select an entry to view transcript, summary, and artifacts."
        static let noRecentTasks = "No tasks yet"
    }

    enum Errors {
        static let networkTitle = "Network Error"
        static let toolMissingTitle = "Tool Missing"
        static let permissionDeniedTitle = "Permission Denied"
        static let diskInsufficientTitle = "Disk Space Insufficient"
        static let operationFailedTitle = "Operation Failed"
    }

    enum Preflight {
        static let title = "Readiness Check"
        static let ready = "Ready"
        static let needsAttention = "Needs Attention"
        static let optional = "Optional"
        static let noIssues = "All startup checks look healthy."
    }

    enum Diagnostics {
        static let title = "Diagnostics"
        static let bundleExportedPrefix = "Diagnostics bundle exported:"
        static let summaryCopied = "Diagnostics summary copied"
        static let checklistExportedPrefix = "Checklist exported:"
        static let checklistSummaryCopied = "Checklist summary copied"
    }

    enum About {
        static let title = "About"
        static let appName = "App"
        static let version = "Version"
        static let build = "Build"
        static let runtimeMode = "Runtime Mode"
        static let databasePath = "Database"
        static let logsPath = "Logs"
        static let cachePath = "Cache"
        static let exportsPath = "Exports"
    }

    enum Support {
        static let title = "Support"
        static let summaryGenerated = "Support summary generated"
    }
}
