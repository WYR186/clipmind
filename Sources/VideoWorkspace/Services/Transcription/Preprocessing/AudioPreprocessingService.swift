import Foundation

struct AudioPreprocessingService: AudioPreprocessingServiceProtocol {
    private let commandBuilder: FFmpegAudioPreprocessCommandBuilder
    private let commandExecutor: any CommandExecuting
    private let toolLocator: any ExternalToolLocating
    private let logger: any AppLoggerProtocol

    init(
        commandBuilder: FFmpegAudioPreprocessCommandBuilder = FFmpegAudioPreprocessCommandBuilder(),
        commandExecutor: any CommandExecuting,
        toolLocator: any ExternalToolLocating,
        logger: any AppLoggerProtocol
    ) {
        self.commandBuilder = commandBuilder
        self.commandExecutor = commandExecutor
        self.toolLocator = toolLocator
        self.logger = logger
    }

    func preprocess(request: TranscriptionRequest) async throws -> AudioPreprocessResult {
        guard request.sourceType == .localFile else {
            throw TranscriptionError.unsupportedSourceType(request.sourceType)
        }

        guard FileManager.default.fileExists(atPath: request.sourcePath) else {
            throw TranscriptionError.sourceFileMissing(path: request.sourcePath)
        }

        if !request.preprocessingRequired {
            return AudioPreprocessResult(
                inputPath: request.sourcePath,
                preparedPath: request.sourcePath,
                usedPreprocessing: false,
                temporaryFiles: []
            )
        }

        let executable: String
        do {
            executable = try toolLocator.locate("ffmpeg")
        } catch {
            throw TranscriptionError.ffmpegNotFound
        }

        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "videoworkspace-transcribe",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let stem = URL(fileURLWithPath: request.sourcePath).deletingPathExtension().lastPathComponent
        let uuid = UUID().uuidString

        let outputURL: URL
        let arguments: [String]
        switch request.backend {
        case .whisperCPP:
            outputURL = tempDirectory.appendingPathComponent("\(stem)-\(uuid)-normalized.wav")
            arguments = commandBuilder.buildWhisperNormalizationArguments(
                inputPath: request.sourcePath,
                outputPath: outputURL.path
            )
        case .openAI:
            outputURL = tempDirectory.appendingPathComponent("\(stem)-\(uuid)-prepared.m4a")
            arguments = commandBuilder.buildOpenAIPreprocessArguments(
                inputPath: request.sourcePath,
                outputPath: outputURL.path
            )
        }

        let result = try await commandExecutor.execute(executable: executable, arguments: arguments)
        guard result.exitCode == 0 else {
            throw TranscriptionError.audioPreprocessFailed(
                details: "path=\(result.executablePath) args=\(result.arguments.joined(separator: " ")) exit=\(result.exitCode) stderr=\(result.stderr)"
            )
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw TranscriptionError.audioPreprocessFailed(details: "ffmpeg produced no output file")
        }

        logger.info("Audio preprocessing completed: \(outputURL.path)")
        return AudioPreprocessResult(
            inputPath: request.sourcePath,
            preparedPath: outputURL.path,
            usedPreprocessing: true,
            temporaryFiles: [outputURL.path]
        )
    }
}
