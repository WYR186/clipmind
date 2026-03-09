import Foundation

protocol CommandExecuting: Sendable {
    func executeStreaming(
        executable: String,
        arguments: [String],
        onOutputLine: (@Sendable (String) -> Void)?
    ) async throws -> CommandExecutionResult

    func execute(executable: String, arguments: [String]) async throws -> CommandExecutionResult
}

extension CommandExecuting {
    func execute(executable: String, arguments: [String]) async throws -> CommandExecutionResult {
        try await executeStreaming(executable: executable, arguments: arguments, onOutputLine: nil)
    }
}
