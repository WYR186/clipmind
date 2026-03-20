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

        let outputPath = deriveOutputPath(for: request)
        let args = buildArguments(for: request, outputPath: outputPath)
        let result = try await commandExecutor.execute(executable: executable, arguments: args)

        guard result.exitCode == 0 else {
            throw DownloadError.commandExecutionFailed(
                diagnostics: ToolExecutionDiagnostics(
                    executablePath: result.executablePath,
                    arguments: result.arguments,
                    exitCode: result.exitCode,
                    stderr: result.stderr,
                    stdoutSnippet: String(result.stdout.prefix(400)),
                    durationMs: result.durationMs
                )
            )
        }

        return ConversionResult(outputPath: outputPath)
    }

    // MARK: Argument dispatch

    private func buildArguments(for request: ConversionRequest, outputPath: String) -> [String] {
        switch request.operation {
        case .remux:
            return commandBuilder.buildRemuxArguments(
                inputPath: request.inputPath,
                outputPath: outputPath
            )

        case .audioExtract:
            let format = AudioOutputFormat(rawValue: request.outputFormat) ?? .mp3
            return commandBuilder.buildAudioExtractionArguments(
                inputPath: request.inputPath,
                outputPath: outputPath,
                format: format,
                quality: request.quality
            )

        case .videoConvert:
            let format = VideoOutputFormat(rawValue: request.outputFormat) ?? .mp4
            return commandBuilder.buildVideoConversionArguments(
                inputPath: request.inputPath,
                outputPath: outputPath,
                format: format,
                quality: request.quality,
                maxWidth: request.maxWidth,
                maxHeight: request.maxHeight
            )

        case .trim:
            return commandBuilder.buildTrimArguments(
                inputPath: request.inputPath,
                outputPath: outputPath,
                startSeconds: request.trimStart ?? 0,
                durationSeconds: request.trimDuration
            )

        case .thumbnail:
            return commandBuilder.buildThumbnailArguments(
                inputPath: request.inputPath,
                outputPath: outputPath,
                atSeconds: request.trimStart ?? 0
            )
        }
    }

    // MARK: Output path

    private func deriveOutputPath(for request: ConversionRequest) -> String {
        let base = URL(fileURLWithPath: request.inputPath).deletingPathExtension().path
        return "\(base).\(request.outputFormat)"
    }
}
