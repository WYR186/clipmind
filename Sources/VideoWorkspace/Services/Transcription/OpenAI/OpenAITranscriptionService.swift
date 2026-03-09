import Foundation

protocol OpenAITranscriptionClientProtocol: Sendable {
    func send(request: URLRequest, body: Data) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionOpenAITranscriptionClient: OpenAITranscriptionClientProtocol {
    func send(request: URLRequest, body: Data) async throws -> (Data, HTTPURLResponse) {
        var mutable = request
        mutable.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: mutable)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.openAIRequestFailed(details: "Non-HTTP response")
        }
        return (data, httpResponse)
    }
}

struct OpenAITranscriptionService: TranscriptionServiceProtocol {
    private let validator: TranscriptionRequestValidator
    private let preprocessor: any AudioPreprocessingServiceProtocol
    private let requestBuilder: OpenAITranscriptionRequestBuilder
    private let mapper: OpenAITranscriptionMapper
    private let transcriptMapper: TranscriptMapper
    private let exporter: any TranscriptExporting
    private let secretsStore: any SecretsStoreProtocol
    private let client: any OpenAITranscriptionClientProtocol
    private let logger: any AppLoggerProtocol

    init(
        validator: TranscriptionRequestValidator = TranscriptionRequestValidator(),
        preprocessor: any AudioPreprocessingServiceProtocol,
        requestBuilder: OpenAITranscriptionRequestBuilder = OpenAITranscriptionRequestBuilder(),
        mapper: OpenAITranscriptionMapper = OpenAITranscriptionMapper(),
        transcriptMapper: TranscriptMapper = TranscriptMapper(),
        exporter: any TranscriptExporting = TranscriptExportWriter(),
        secretsStore: any SecretsStoreProtocol,
        client: any OpenAITranscriptionClientProtocol = URLSessionOpenAITranscriptionClient(),
        logger: any AppLoggerProtocol
    ) {
        self.validator = validator
        self.preprocessor = preprocessor
        self.requestBuilder = requestBuilder
        self.mapper = mapper
        self.transcriptMapper = transcriptMapper
        self.exporter = exporter
        self.secretsStore = secretsStore
        self.client = client
        self.logger = logger
    }

    func transcribe(
        request: TranscriptionRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranscriptionResult {
        guard request.backend == .openAI else {
            throw TranscriptionError.backendUnavailable(request.backend)
        }

        try validator.validate(request)
        progressHandler?(TaskProgressFactory.step(0.05, description: "Validating request"))

        guard let apiKey = try await secretsStore.getSecret(for: ProviderType.openAI.rawValue),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionError.openAIKeyMissing
        }

        let preprocessResult = try await preprocessor.preprocess(request: request)
        defer {
            cleanupTemporaryFiles(preprocessResult.temporaryFiles)
        }

        progressHandler?(TaskProgressFactory.step(0.2, description: "Uploading audio"))

        let preparedFileURL = URL(fileURLWithPath: preprocessResult.preparedPath)
        let builtRequest: OpenAITranscriptionBuiltRequest
        do {
            builtRequest = try requestBuilder.build(request: request, fileURL: preparedFileURL, apiKey: apiKey)
        } catch {
            throw TranscriptionError.openAIRequestFailed(details: "Failed to build request: \(error.localizedDescription)")
        }

        let responseData: Data
        let response: HTTPURLResponse
        do {
            (responseData, response) = try await client.send(request: builtRequest.urlRequest, body: builtRequest.body)
        } catch {
            throw TranscriptionError.openAIRequestFailed(details: error.localizedDescription)
        }

        guard (200...299).contains(response.statusCode) else {
            let snippet = String(data: responseData.prefix(300), encoding: .utf8) ?? ""
            throw TranscriptionError.openAIRequestFailed(details: "status=\(response.statusCode) body=\(snippet)")
        }

        progressHandler?(TaskProgressFactory.step(0.75, description: "Processing response"))

        let decoded: OpenAITranscriptionResponse
        do {
            decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: responseData)
        } catch {
            throw TranscriptionError.openAIResponseDecodeFailed(details: error.localizedDescription)
        }

        let segments = mapper.mapSegments(from: decoded)
        let artifacts = try exporter.write(
            request: request,
            transcriptText: decoded.text,
            segments: segments
        )

        let primaryFormat = artifacts.first?.kind.toTranscriptFormat ?? .txt
        let transcript = transcriptMapper.mapToTranscriptItem(
            taskID: request.taskID,
            format: primaryFormat,
            content: decoded.text,
            languageCode: request.languageHint ?? decoded.language ?? "unknown",
            sourceType: .asr,
            segments: segments,
            artifacts: artifacts,
            backend: .openAI,
            modelID: request.modelIdentifier,
            detectedLanguage: decoded.language
        )

        progressHandler?(TaskProgressFactory.step(1.0, description: "Transcription completed"))
        logger.info("OpenAI transcription completed for task=\(request.taskID)")

        return TranscriptionResult(
            transcript: transcript,
            artifacts: artifacts,
            backendUsed: .openAI,
            modelUsed: request.modelIdentifier,
            detectedLanguage: decoded.language,
            durationSeconds: decoded.duration,
            diagnostics: request.debugDiagnosticsEnabled ? "openai_status=\(response.statusCode)" : nil
        )
    }

    private func cleanupTemporaryFiles(_ paths: [String]) {
        for path in paths {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                logger.debug("Failed to remove temp file: \(path)")
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
