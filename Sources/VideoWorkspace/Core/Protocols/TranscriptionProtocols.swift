import Foundation

public protocol TranscriptionServiceProtocol: Sendable {
    func transcribe(
        request: TranscriptionRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranscriptionResult
}

public protocol AudioPreprocessingServiceProtocol: Sendable {
    func preprocess(request: TranscriptionRequest) async throws -> AudioPreprocessResult
}

public protocol TranscriptExporting: Sendable {
    func write(
        request: TranscriptionRequest,
        transcriptText: String,
        segments: [TranscriptSegment]
    ) throws -> [TranscriptArtifact]
}

public extension TranscriptionServiceProtocol {
    func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResult {
        try await transcribe(request: request, progressHandler: nil)
    }

    // TODO: Remove compatibility bridge after OnlineVideo flow migrates to request-based transcription.
    func transcribe(taskID: UUID, source: MediaSource, preferredLanguage: String) async throws -> TranscriptItem {
        if source.type == .url {
            return TranscriptItem(
                taskID: taskID,
                sourceType: .native,
                languageCode: preferredLanguage,
                format: .txt,
                content: "Transcript placeholder for online source. Use subtitle extraction or local transcription flow."
            )
        }

        let request = TranscriptionRequest(
            taskID: taskID,
            sourcePath: source.value,
            sourceType: source.type,
            backend: .openAI,
            modelIdentifier: "gpt-4o-mini-transcribe",
            outputKinds: [.txt],
            languageHint: preferredLanguage,
            promptHint: nil,
            temperature: nil,
            outputDirectory: nil,
            overwritePolicy: .renameIfNeeded,
            preprocessingRequired: true,
            debugDiagnosticsEnabled: false,
            whisperExecutablePath: nil,
            whisperModelPath: nil
        )
        let result = try await transcribe(request: request, progressHandler: nil)
        return result.transcript
    }
}
