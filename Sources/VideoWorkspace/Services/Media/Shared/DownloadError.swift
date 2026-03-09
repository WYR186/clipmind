import Foundation

enum DownloadError: Error, Sendable {
    case invalidSelection(reason: String)
    case outputDirectoryUnavailable(path: String)
    case filenameResolutionFailed(reason: String)
    case ytDLPNotFound
    case ffmpegNotFound
    case commandExecutionFailed(diagnostics: ToolExecutionDiagnostics)
    case progressParseFailed(line: String)
    case outputNotProduced(expectedDirectory: String)
}

extension DownloadError {
    var userMessage: String {
        switch self {
        case let .invalidSelection(reason):
            return reason
        case let .outputDirectoryUnavailable(path):
            return "Output directory is unavailable: \(path)"
        case .filenameResolutionFailed:
            return "Failed to resolve output file name."
        case .ytDLPNotFound:
            return "yt-dlp is not installed."
        case .ffmpegNotFound:
            return "ffmpeg is not installed."
        case .commandExecutionFailed:
            return "Download command failed."
        case .progressParseFailed:
            return "Failed to parse progress output."
        case .outputNotProduced:
            return "Download completed but output file was not found."
        }
    }

    var diagnostics: String {
        switch self {
        case let .invalidSelection(reason):
            return "invalid_selection=\(reason)"
        case let .outputDirectoryUnavailable(path):
            return "output_directory_unavailable=\(path)"
        case let .filenameResolutionFailed(reason):
            return "filename_resolution_failed=\(reason)"
        case .ytDLPNotFound:
            return "yt_dlp_not_found"
        case .ffmpegNotFound:
            return "ffmpeg_not_found"
        case let .commandExecutionFailed(diagnostics):
            return "command_failed path=\(diagnostics.executablePath) args=\(diagnostics.arguments.joined(separator: " ")) exit=\(diagnostics.exitCode.map(String.init) ?? "n/a") stderr=\(diagnostics.stderr) stdout_snippet=\(diagnostics.stdoutSnippet) duration_ms=\(diagnostics.durationMs.map(String.init) ?? "n/a")"
        case let .progressParseFailed(line):
            return "progress_parse_failed line=\(line)"
        case let .outputNotProduced(expectedDirectory):
            return "output_not_produced expected_directory=\(expectedDirectory)"
        }
    }
}
