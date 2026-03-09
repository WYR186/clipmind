import Foundation

struct ToolExecutionDiagnostics: Sendable {
    let executablePath: String
    let arguments: [String]
    let exitCode: Int32?
    let stderr: String
    let stdoutSnippet: String
    let durationMs: Int?
}

enum ExternalToolError: Error, Sendable {
    case toolNotFound(tool: String, searchedPaths: [String])
    case invalidSource(reason: String)
    case unsupportedSourceType(SourceType)
    case executionFailed(tool: String, diagnostics: ToolExecutionDiagnostics)
    case invalidOutput(tool: String, diagnostics: ToolExecutionDiagnostics)
    case decodeFailed(tool: String, diagnostics: ToolExecutionDiagnostics)
}

extension ExternalToolError {
    var userMessage: String {
        switch self {
        case let .toolNotFound(tool, _):
            return "Required tool is missing: \(tool)."
        case .invalidSource:
            return "The input source is invalid."
        case .unsupportedSourceType:
            return "The source type is not supported."
        case let .executionFailed(tool, _):
            return "Failed to inspect media via \(tool)."
        case let .invalidOutput(tool, _):
            return "\(tool) returned an invalid output."
        case let .decodeFailed(tool, _):
            return "Failed to decode \(tool) inspection output."
        }
    }

    var diagnostics: String {
        switch self {
        case let .toolNotFound(tool, searchedPaths):
            return "tool=\(tool) searched=\(searchedPaths.joined(separator: ","))"
        case let .invalidSource(reason):
            return "invalid_source=\(reason)"
        case let .unsupportedSourceType(sourceType):
            return "unsupported_source_type=\(sourceType.rawValue)"
        case let .executionFailed(tool, details),
             let .invalidOutput(tool, details),
             let .decodeFailed(tool, details):
            return "tool=\(tool) path=\(details.executablePath) args=\(details.arguments.joined(separator: " ")) exit=\(details.exitCode.map(String.init) ?? "n/a") stderr=\(details.stderr) stdout_snippet=\(details.stdoutSnippet) duration_ms=\(details.durationMs.map(String.init) ?? "n/a")"
        }
    }
}
