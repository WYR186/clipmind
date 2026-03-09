import Foundation

struct FFmpegMediaConversionService: MediaConversionServiceProtocol {
    private let commandBuilder: FFmpegCommandBuilder
    private let commandExecutor: any CommandExecuting
    private let toolLocator: any ExternalToolLocating

    init(
        commandBuilder: FFmpegCommandBuilder = FFmpegCommandBuilder(),
        commandExecutor: any CommandExecuting,
        toolLocator: any ExternalToolLocating
    ) {
        self.commandBuilder = commandBuilder
        self.commandExecutor = commandExecutor
        self.toolLocator = toolLocator
    }

    func convert(request: ConversionRequest) async throws -> ConversionResult {
        let executable: String
        do {
            executable = try toolLocator.locate("ffmpeg")
        } catch {
            throw DownloadError.ffmpegNotFound
        }

        let outputPath = request.inputPath + "." + request.outputFormat
        let args = commandBuilder.buildRemuxArguments(inputPath: request.inputPath, outputPath: outputPath)
        let result = try await commandExecutor.execute(executable: executable, arguments: args)

        guard result.exitCode == 0 else {
            throw DownloadError.commandExecutionFailed(
                diagnostics: ToolExecutionDiagnostics(
                    executablePath: result.executablePath,
                    arguments: result.arguments,
                    exitCode: result.exitCode,
                    stderr: result.stderr,
                    stdoutSnippet: String(result.stdout.prefix(200)),
                    durationMs: result.durationMs
                )
            )
        }

        return ConversionResult(outputPath: outputPath)
    }
}
