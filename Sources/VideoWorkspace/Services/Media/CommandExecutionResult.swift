import Foundation

struct CommandExecutionResult: Sendable {
    let executablePath: String
    let arguments: [String]
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let durationMs: Int
}
