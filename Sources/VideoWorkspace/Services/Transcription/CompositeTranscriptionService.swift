import Foundation

struct CompositeTranscriptionService: TranscriptionServiceProtocol {
    private let openAIService: any TranscriptionServiceProtocol
    private let whisperService: any TranscriptionServiceProtocol
    private let fallbackService: (any TranscriptionServiceProtocol)?
    private let allowFallbackToMock: Bool
    private let logger: any AppLoggerProtocol

    init(
        openAIService: any TranscriptionServiceProtocol,
        whisperService: any TranscriptionServiceProtocol,
        fallbackService: (any TranscriptionServiceProtocol)? = nil,
        allowFallbackToMock: Bool,
        logger: any AppLoggerProtocol
    ) {
        self.openAIService = openAIService
        self.whisperService = whisperService
        self.fallbackService = fallbackService
        self.allowFallbackToMock = allowFallbackToMock
        self.logger = logger
    }

    func transcribe(
        request: TranscriptionRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> TranscriptionResult {
        let service: any TranscriptionServiceProtocol
        switch request.backend {
        case .openAI:
            service = openAIService
        case .whisperCPP:
            service = whisperService
        }

        do {
            return try await service.transcribe(request: request, progressHandler: progressHandler)
        } catch {
            logger.error("Primary transcription backend failed: \(error.localizedDescription)")
            guard shouldFallback(for: error),
                  let fallbackService else {
                throw error
            }

            logger.info("Falling back to mock transcription service")
            return try await fallbackService.transcribe(request: request, progressHandler: progressHandler)
        }
    }

    private func shouldFallback(for error: Error) -> Bool {
        guard allowFallbackToMock else { return false }
        guard let typed = error as? TranscriptionError else {
            return false
        }

        switch typed {
        case .backendUnavailable:
            return true
        case .sourceFileMissing,
                .invalidTranscriptionRequest,
                .openAIKeyMissing,
                .whisperExecutableNotFound,
                .whisperModelNotFound:
            return false
        default:
            return false
        }
    }
}
