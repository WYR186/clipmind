import Foundation

struct ProcessCommandExecutor: CommandExecuting {
    func executeStreaming(
        executable: String,
        arguments: [String],
        onOutputLine: (@Sendable (String) -> Void)?
    ) async throws -> CommandExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let start = Date()
        try process.run()

        let stdoutTask = Task {
            await collectOutput(from: stdoutPipe.fileHandleForReading, onOutputLine: onOutputLine)
        }
        let stderrTask = Task {
            await collectOutput(from: stderrPipe.fileHandleForReading, onOutputLine: onOutputLine)
        }

        let exitCode: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { terminated in
                continuation.resume(returning: terminated.terminationStatus)
            }
        }

        let stdout = await stdoutTask.value
        let stderr = await stderrTask.value

        return CommandExecutionResult(
            executablePath: executable,
            arguments: arguments,
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            durationMs: Int(Date().timeIntervalSince(start) * 1000)
        )
    }

    private func collectOutput(
        from handle: FileHandle,
        onOutputLine: (@Sendable (String) -> Void)?
    ) async -> String {
        var text = ""
        var lineBuffer = ""

        do {
            for try await byte in handle.bytes {
                let character = Character(UnicodeScalar(byte))
                text.append(character)

                if character == "\n" {
                    let line = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty {
                        onOutputLine?(line)
                    }
                    lineBuffer = ""
                } else if character != "\r" {
                    lineBuffer.append(character)
                }
            }

            let trailing = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trailing.isEmpty {
                onOutputLine?(trailing)
            }
        } catch {
            // TODO: Add dedicated stream read diagnostics if needed.
        }

        return text
    }
}
