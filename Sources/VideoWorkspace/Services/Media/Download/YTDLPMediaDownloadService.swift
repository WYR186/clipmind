import Foundation

struct YTDLPMediaDownloadService: MediaDownloadServiceProtocol {
    private let commandBuilder: YTDLPDownloadCommandBuilder
    private let outputResolver: DownloadOutputResolver
    private let progressParser: DownloadProgressParser
    private let commandExecutor: any CommandExecuting
    private let toolLocator: any ExternalToolLocating
    private let logger: any AppLoggerProtocol

    init(
        commandBuilder: YTDLPDownloadCommandBuilder = YTDLPDownloadCommandBuilder(),
        outputResolver: DownloadOutputResolver = DownloadOutputResolver(),
        progressParser: DownloadProgressParser = DownloadProgressParser(),
        commandExecutor: any CommandExecuting,
        toolLocator: any ExternalToolLocating,
        logger: any AppLoggerProtocol
    ) {
        self.commandBuilder = commandBuilder
        self.outputResolver = outputResolver
        self.progressParser = progressParser
        self.commandExecutor = commandExecutor
        self.toolLocator = toolLocator
        self.logger = logger
    }

    func download(
        request: MediaDownloadRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> MediaDownloadResult {
        guard request.source.type == .url else {
            throw DownloadError.invalidSelection(reason: "Online URL is required for yt-dlp download.")
        }

        let executable: String
        do {
            executable = try toolLocator.locate("yt-dlp")
        } catch {
            throw DownloadError.ytDLPNotFound
        }

        let preparedOutput: PreparedDownloadOutput
        do {
            preparedOutput = try outputResolver.prepareOutput(request: request, metadata: nil)
        } catch let error as OutputPathError {
            switch error {
            case let .invalidDirectory(path), let .cannotCreateDirectory(path):
                throw DownloadError.outputDirectoryUnavailable(path: path)
            case .noResolvedPath:
                throw DownloadError.filenameResolutionFailed(reason: "No resolved path")
            }
        }

        let arguments = try commandBuilder.buildArguments(request: request, outputTemplatePath: preparedOutput.outputTemplatePath)

        let outputPathBox = DownloadOutputPathBox()
        let result = try await commandExecutor.executeStreaming(
            executable: executable,
            arguments: arguments,
            onOutputLine: { line in
                if let event = progressParser.parse(line: line) {
                    if let progress = event.progress {
                        progressHandler?(progress)
                    }
                    if let resolvedPath = event.resolvedOutputPath {
                        outputPathBox.set(resolvedPath)
                    }
                }
            }
        )

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

        let finalPath = outputResolver.resolveFinalOutputPath(prepared: preparedOutput, preferredPath: outputPathBox.get())
        guard let finalPath else {
            throw DownloadError.outputNotProduced(expectedDirectory: preparedOutput.directoryURL.path)
        }

        logger.info("yt-dlp download succeeded: \(finalPath)")
        progressHandler?(TaskProgressFactory.step(1.0, description: "Download completed"))

        return MediaDownloadResult(
            kind: request.kind,
            outputPath: finalPath,
            outputFileName: URL(fileURLWithPath: finalPath).lastPathComponent,
            usedVideoFormatID: request.selectedVideoFormatID,
            usedAudioFormatID: request.selectedAudioFormatID,
            subtitleLanguage: request.selectedSubtitleTrack?.languageCode
        )
    }
}

private final class DownloadOutputPathBox: @unchecked Sendable {
    private var value: String?
    private let lock = NSLock()

    func set(_ newValue: String) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func get() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
