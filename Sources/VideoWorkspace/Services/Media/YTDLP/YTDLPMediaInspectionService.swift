import Foundation

struct YTDLPMediaInspectionService: MediaInspectionServiceProtocol {
    private let commandBuilder: YTDLPCommandBuilder
    private let commandExecutor: any CommandExecuting
    private let toolLocator: any ExternalToolLocating
    private let mapper: YTDLPMapper
    private let logger: any AppLoggerProtocol

    init(
        commandBuilder: YTDLPCommandBuilder = YTDLPCommandBuilder(),
        commandExecutor: any CommandExecuting,
        toolLocator: any ExternalToolLocating,
        mapper: YTDLPMapper = YTDLPMapper(),
        logger: any AppLoggerProtocol
    ) {
        self.commandBuilder = commandBuilder
        self.commandExecutor = commandExecutor
        self.toolLocator = toolLocator
        self.mapper = mapper
        self.logger = logger
    }

    func inspect(source: MediaSource) async throws -> MediaMetadata {
        guard source.type == .url else {
            throw MediaInspectionError.external(.unsupportedSourceType(source.type))
        }
        guard let url = URL(string: source.value), let scheme = url.scheme, ["http", "https"].contains(scheme) else {
            throw MediaInspectionError.external(.invalidSource(reason: "Invalid URL format"))
        }

        do {
            let executablePath = try toolLocator.locate("yt-dlp")
            let arguments = commandBuilder.buildInspectArguments(url: source.value)
            let result = try await commandExecutor.execute(executable: executablePath, arguments: arguments)

            if result.exitCode != 0 {
                throw MediaInspectionError.external(.executionFailed(
                    tool: "yt-dlp",
                    diagnostics: ToolExecutionDiagnostics(
                        executablePath: result.executablePath,
                        arguments: result.arguments,
                        exitCode: result.exitCode,
                        stderr: result.stderr,
                        stdoutSnippet: String(result.stdout.prefix(400)),
                        durationMs: result.durationMs
                    )
                ))
            }

            guard !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MediaInspectionError.external(.invalidOutput(
                    tool: "yt-dlp",
                    diagnostics: ToolExecutionDiagnostics(
                        executablePath: result.executablePath,
                        arguments: result.arguments,
                        exitCode: result.exitCode,
                        stderr: result.stderr,
                        stdoutSnippet: "",
                        durationMs: result.durationMs
                    )
                ))
            }

            let data = Data(result.stdout.utf8)
            let payload: YTDLPJSONModels.Root
            do {
                payload = try JSONDecoder().decode(YTDLPJSONModels.Root.self, from: data)
            } catch {
                throw MediaInspectionError.external(.decodeFailed(
                    tool: "yt-dlp",
                    diagnostics: ToolExecutionDiagnostics(
                        executablePath: result.executablePath,
                        arguments: result.arguments,
                        exitCode: result.exitCode,
                        stderr: result.stderr,
                        stdoutSnippet: String(result.stdout.prefix(400)),
                        durationMs: result.durationMs
                    )
                ))
            }

            let mapped = try mapper.map(source: source, payload: payload)
            logger.info("yt-dlp inspection succeeded: \(source.value)")
            return mapped
        } catch let error as MediaInspectionError {
            logger.error("yt-dlp inspection failed: \(error.diagnostics)")
            throw error
        } catch let error as ExternalToolError {
            let wrapped = MediaInspectionError.external(error)
            logger.error("yt-dlp inspection failed: \(wrapped.diagnostics)")
            throw wrapped
        } catch {
            let wrapped = MediaInspectionError.failed(reason: error.localizedDescription)
            logger.error("yt-dlp inspection failed: \(wrapped.diagnostics)")
            throw wrapped
        }
    }
}
