import Foundation

struct FFprobeMediaInspectionService: MediaInspectionServiceProtocol {
    private let commandBuilder: FFprobeCommandBuilder
    private let commandExecutor: any CommandExecuting
    private let toolLocator: any ExternalToolLocating
    private let mapper: FFprobeMapper
    private let logger: any AppLoggerProtocol

    init(
        commandBuilder: FFprobeCommandBuilder = FFprobeCommandBuilder(),
        commandExecutor: any CommandExecuting,
        toolLocator: any ExternalToolLocating,
        mapper: FFprobeMapper = FFprobeMapper(),
        logger: any AppLoggerProtocol
    ) {
        self.commandBuilder = commandBuilder
        self.commandExecutor = commandExecutor
        self.toolLocator = toolLocator
        self.mapper = mapper
        self.logger = logger
    }

    func inspect(source: MediaSource) async throws -> MediaMetadata {
        guard source.type == .localFile else {
            throw MediaInspectionError.external(.unsupportedSourceType(source.type))
        }
        guard FileManager.default.fileExists(atPath: source.value) else {
            throw MediaInspectionError.external(.invalidSource(reason: "Local file does not exist"))
        }

        do {
            let executablePath = try toolLocator.locate("ffprobe")
            let arguments = commandBuilder.buildInspectArguments(filePath: source.value)
            let result = try await commandExecutor.execute(executable: executablePath, arguments: arguments)

            if result.exitCode != 0 {
                throw MediaInspectionError.external(.executionFailed(
                    tool: "ffprobe",
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
                    tool: "ffprobe",
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
            let payload: FFprobeJSONModels.Root
            do {
                payload = try JSONDecoder().decode(FFprobeJSONModels.Root.self, from: data)
            } catch {
                throw MediaInspectionError.external(.decodeFailed(
                    tool: "ffprobe",
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
            logger.info("ffprobe inspection succeeded: \(source.value)")
            return mapped
        } catch let error as MediaInspectionError {
            logger.error("ffprobe inspection failed: \(error.diagnostics)")
            throw error
        } catch let error as ExternalToolError {
            let wrapped = MediaInspectionError.external(error)
            logger.error("ffprobe inspection failed: \(wrapped.diagnostics)")
            throw wrapped
        } catch {
            let wrapped = MediaInspectionError.failed(reason: error.localizedDescription)
            logger.error("ffprobe inspection failed: \(wrapped.diagnostics)")
            throw wrapped
        }
    }
}
