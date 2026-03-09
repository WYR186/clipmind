import XCTest
@testable import VideoWorkspace

final class AudioPreprocessingTests: XCTestCase {
    func testPreprocessCreatesNormalizedOutput() async throws {
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("audio-source-\(UUID().uuidString).mp4")
        try Data("video".utf8).write(to: sourceURL)

        let request = TranscriptionRequest(
            taskID: UUID(),
            sourcePath: sourceURL.path,
            sourceType: .localFile,
            backend: .whisperCPP,
            modelIdentifier: "base",
            outputKinds: [.txt],
            languageHint: nil,
            promptHint: nil,
            temperature: nil,
            outputDirectory: nil,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: true,
            debugDiagnosticsEnabled: false,
            whisperExecutablePath: nil,
            whisperModelPath: nil
        )

        let service = AudioPreprocessingService(
            commandExecutor: StubPreprocessExecutor(),
            toolLocator: StubPreprocessToolLocator(),
            logger: ConsoleLogger()
        )

        let result = try await service.preprocess(request: request)

        XCTAssertTrue(result.usedPreprocessing)
        XCTAssertTrue(result.preparedPath.hasSuffix(".wav"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.preparedPath))
    }
}

private struct StubPreprocessToolLocator: ExternalToolLocating {
    func locate(_ toolName: String) throws -> String {
        "/usr/local/bin/\(toolName)"
    }
}

private struct StubPreprocessExecutor: CommandExecuting {
    func executeStreaming(
        executable: String,
        arguments: [String],
        onOutputLine: (@Sendable (String) -> Void)?
    ) async throws -> CommandExecutionResult {
        if let output = arguments.last {
            FileManager.default.createFile(atPath: output, contents: Data("wav".utf8))
        }

        return CommandExecutionResult(
            executablePath: executable,
            arguments: arguments,
            exitCode: 0,
            stdout: "",
            stderr: "",
            durationMs: 50
        )
    }

    func execute(executable: String, arguments: [String]) async throws -> CommandExecutionResult {
        try await executeStreaming(executable: executable, arguments: arguments, onOutputLine: nil)
    }
}
