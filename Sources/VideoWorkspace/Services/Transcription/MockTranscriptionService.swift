import Foundation

struct MockTranscriptionService: TranscriptionServiceProtocol {
    func transcribe(
        request: TranscriptionRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranscriptionResult {
        progressHandler?(TaskProgressFactory.step(0.2, description: "Mock preprocessing"))
        try await Task.sleep(nanoseconds: 800_000_000)
        progressHandler?(TaskProgressFactory.step(0.8, description: "Mock transcription"))

        let transcript = TranscriptItem(
            taskID: request.taskID,
            sourceType: request.sourceType == .url ? .native : .asr,
            languageCode: request.languageHint ?? "en",
            format: .txt,
            content: MockSamples.transcriptText,
            segments: [],
            artifacts: [],
            backend: request.backend,
            modelID: request.modelIdentifier,
            detectedLanguage: request.languageHint
        )

        progressHandler?(TaskProgressFactory.step(1.0, description: "Mock complete"))
        return TranscriptionResult(
            transcript: transcript,
            artifacts: [],
            backendUsed: request.backend,
            modelUsed: request.modelIdentifier,
            detectedLanguage: request.languageHint,
            durationSeconds: nil,
            diagnostics: "mock_transcription=true"
        )
    }
}
