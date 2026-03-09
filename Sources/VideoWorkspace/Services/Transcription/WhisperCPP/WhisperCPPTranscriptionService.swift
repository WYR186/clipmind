import Foundation

struct WhisperCPPTranscriptionService: TranscriptionServiceProtocol {
    private let validator: TranscriptionRequestValidator
    private let preprocessor: any AudioPreprocessingServiceProtocol
    private let locator: WhisperCPPLocator
    private let commandBuilder: WhisperCPPCommandBuilder
    private let outputParser: WhisperCPPOutputParser
    private let transcriptMapper: TranscriptMapper
    private let exporter: any TranscriptExporting
    private let commandExecutor: any CommandExecuting
    private let logger: any AppLoggerProtocol

    init(
        validator: TranscriptionRequestValidator = TranscriptionRequestValidator(),
        preprocessor: any AudioPreprocessingServiceProtocol,
        locator: WhisperCPPLocator,
        commandBuilder: WhisperCPPCommandBuilder = WhisperCPPCommandBuilder(),
        outputParser: WhisperCPPOutputParser = WhisperCPPOutputParser(),
        transcriptMapper: TranscriptMapper = TranscriptMapper(),
        exporter: any TranscriptExporting = TranscriptExportWriter(),
        commandExecutor: any CommandExecuting,
        logger: any AppLoggerProtocol
    ) {
        self.validator = validator
        self.preprocessor = preprocessor
        self.locator = locator
        self.commandBuilder = commandBuilder
        self.outputParser = outputParser
        self.transcriptMapper = transcriptMapper
        self.exporter = exporter
        self.commandExecutor = commandExecutor
        self.logger = logger
    }

    func transcribe(
        request: TranscriptionRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranscriptionResult {
        guard request.backend == .whisperCPP else {
            throw TranscriptionError.backendUnavailable(request.backend)
        }

        try validator.validate(request)
        progressHandler?(TaskProgressFactory.step(0.05, description: "Validating request"))

        let executable = try locator.locateExecutable(customPath: request.whisperExecutablePath)
        let preprocessResult = try await preprocessor.preprocess(request: request)

        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "videoworkspace-whisper",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let baseName = URL(fileURLWithPath: request.sourcePath).deletingPathExtension().lastPathComponent
        let outputBasePath = tempDirectory.appendingPathComponent("\(baseName)-\(request.taskID.uuidString)").path

        let arguments = try commandBuilder.buildArguments(
            request: request,
            inputAudioPath: preprocessResult.preparedPath,
            outputBasePath: outputBasePath
        )

        progressHandler?(TaskProgressFactory.step(0.2, description: "Running whisper.cpp"))

        let result = try await commandExecutor.executeStreaming(
            executable: executable,
            arguments: arguments,
            onOutputLine: { line in
                if let progress = parseWhisperProgress(line: line) {
                    progressHandler?(TaskProgressFactory.step(0.2 + progress * 0.6, description: "Transcribing \(Int(progress * 100))%"))
                }
            }
        )

        guard result.exitCode == 0 else {
            throw TranscriptionError.whisperExecutionFailed(
                details: "whisper path=\(result.executablePath) args=\(result.arguments.joined(separator: " ")) exit=\(result.exitCode) stderr=\(result.stderr)"
            )
        }

        progressHandler?(TaskProgressFactory.step(0.85, description: "Exporting transcript"))

        let parsed = try outputParser.parse(outputBasePath: outputBasePath)
        let artifacts = try exporter.write(
            request: request,
            transcriptText: parsed.text,
            segments: parsed.segments
        )

        let transcript = transcriptMapper.mapToTranscriptItem(
            taskID: request.taskID,
            format: artifacts.first?.kind.toTranscriptFormat ?? .txt,
            content: parsed.text,
            languageCode: request.languageHint ?? "unknown",
            sourceType: .asr,
            segments: parsed.segments,
            artifacts: artifacts,
            backend: .whisperCPP,
            modelID: request.modelIdentifier,
            detectedLanguage: request.languageHint
        )

        progressHandler?(TaskProgressFactory.step(1.0, description: "Transcription completed"))
        logger.info("whisper.cpp transcription completed for task=\(request.taskID)")

        cleanupTemporaryFiles(preprocessResult.temporaryFiles + temporaryOutputFiles(basePath: outputBasePath))

        return TranscriptionResult(
            transcript: transcript,
            artifacts: artifacts,
            backendUsed: .whisperCPP,
            modelUsed: request.modelIdentifier,
            detectedLanguage: request.languageHint,
            durationSeconds: parsed.segments.last?.endSeconds,
            diagnostics: request.debugDiagnosticsEnabled ? "whisper_exit=\(result.exitCode)" : nil
        )
    }

    private func parseWhisperProgress(line: String) -> Double? {
        let pattern = #"\b([0-9]{1,3})%\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: nsRange),
              let range = Range(match.range(at: 1), in: line),
              let percent = Double(line[range]) else {
            return nil
        }
        return min(max(percent / 100, 0), 1)
    }

    private func temporaryOutputFiles(basePath: String) -> [String] {
        [
            basePath + ".txt",
            basePath + ".srt",
            basePath + ".vtt"
        ]
    }

    private func cleanupTemporaryFiles(_ paths: [String]) {
        for path in paths where FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                logger.debug("Failed to cleanup whisper temp file: \(path)")
            }
        }
    }
}

private extension TranscriptOutputKind {
    var toTranscriptFormat: TranscriptFormat {
        switch self {
        case .txt:
            return .txt
        case .srt:
            return .srt
        case .vtt:
            return .vtt
        }
    }
}
