import XCTest
@testable import VideoWorkspace

final class CompositeTranscriptionServiceTests: XCTestCase {
    func testRoutesToOpenAIBackend() async throws {
        let openAI = StubTranscriptionService(resultBackend: .openAI)
        let whisper = StubTranscriptionService(resultBackend: .whisperCPP)

        let service = CompositeTranscriptionService(
            openAIService: openAI,
            whisperService: whisper,
            fallbackService: nil,
            allowFallbackToMock: false,
            logger: ConsoleLogger()
        )

        let request = makeRequest(backend: .openAI)
        let result = try await service.transcribe(request: request, progressHandler: nil)

        XCTAssertEqual(result.backendUsed, .openAI)
        XCTAssertEqual(openAI.invocationCount, 1)
        XCTAssertEqual(whisper.invocationCount, 0)
    }

    func testFallbackForBackendUnavailable() async throws {
        let openAI = StubTranscriptionService(error: .backendUnavailable(.openAI))
        let whisper = StubTranscriptionService(resultBackend: .whisperCPP)
        let fallback = StubTranscriptionService(resultBackend: .openAI)

        let service = CompositeTranscriptionService(
            openAIService: openAI,
            whisperService: whisper,
            fallbackService: fallback,
            allowFallbackToMock: true,
            logger: ConsoleLogger()
        )

        let result = try await service.transcribe(request: makeRequest(backend: .openAI), progressHandler: nil)
        XCTAssertEqual(result.backendUsed, .openAI)
        XCTAssertEqual(fallback.invocationCount, 1)
    }

    func testNoFallbackForOpenAIKeyMissing() async {
        let openAI = StubTranscriptionService(error: .openAIKeyMissing)
        let whisper = StubTranscriptionService(resultBackend: .whisperCPP)
        let fallback = StubTranscriptionService(resultBackend: .openAI)

        let service = CompositeTranscriptionService(
            openAIService: openAI,
            whisperService: whisper,
            fallbackService: fallback,
            allowFallbackToMock: true,
            logger: ConsoleLogger()
        )

        do {
            _ = try await service.transcribe(request: makeRequest(backend: .openAI), progressHandler: nil)
            XCTFail("Expected error")
        } catch let error as TranscriptionError {
            if case .openAIKeyMissing = error {
                XCTAssertEqual(fallback.invocationCount, 0)
            } else {
                XCTFail("Unexpected error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeRequest(backend: TranscriptionBackend) -> TranscriptionRequest {
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("composite-src-\(UUID().uuidString).wav")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data("a".utf8))

        return TranscriptionRequest(
            taskID: UUID(),
            sourcePath: sourceURL.path,
            sourceType: .localFile,
            backend: backend,
            modelIdentifier: "model",
            outputKinds: [.txt],
            languageHint: "en",
            promptHint: nil,
            temperature: nil,
            outputDirectory: nil,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: false,
            debugDiagnosticsEnabled: false,
            whisperExecutablePath: nil,
            whisperModelPath: sourceURL.path
        )
    }
}

private final class StubTranscriptionService: @unchecked Sendable, TranscriptionServiceProtocol {
    private(set) var invocationCount: Int = 0
    private let resultBackend: TranscriptionBackend?
    private let error: TranscriptionError?

    init(resultBackend: TranscriptionBackend) {
        self.resultBackend = resultBackend
        self.error = nil
    }

    init(error: TranscriptionError) {
        self.resultBackend = nil
        self.error = error
    }

    func transcribe(
        request: TranscriptionRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranscriptionResult {
        invocationCount += 1
        if let error {
            throw error
        }

        let transcript = TranscriptItem(
            taskID: request.taskID,
            sourceType: .asr,
            languageCode: "en",
            format: .txt,
            content: "ok",
            backend: resultBackend,
            modelID: request.modelIdentifier
        )

        return TranscriptionResult(
            transcript: transcript,
            artifacts: [],
            backendUsed: resultBackend ?? .openAI,
            modelUsed: request.modelIdentifier,
            detectedLanguage: "en",
            durationSeconds: 1,
            diagnostics: nil
        )
    }
}
