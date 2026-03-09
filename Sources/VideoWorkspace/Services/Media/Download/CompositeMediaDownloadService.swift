import Foundation

struct CompositeMediaDownloadService: MediaDownloadServiceProtocol {
    private let onlineDownloadService: any MediaDownloadServiceProtocol
    private let fallbackDownloadService: (any MediaDownloadServiceProtocol)?
    private let allowFallbackToMock: Bool
    private let logger: any AppLoggerProtocol

    init(
        onlineDownloadService: any MediaDownloadServiceProtocol,
        fallbackDownloadService: (any MediaDownloadServiceProtocol)?,
        allowFallbackToMock: Bool,
        logger: any AppLoggerProtocol
    ) {
        self.onlineDownloadService = onlineDownloadService
        self.fallbackDownloadService = fallbackDownloadService
        self.allowFallbackToMock = allowFallbackToMock
        self.logger = logger
    }

    func download(
        request: MediaDownloadRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> MediaDownloadResult {
        if request.source.type == .localFile {
            guard let fallbackDownloadService else {
                throw DownloadError.invalidSelection(reason: "Local download is not implemented in this phase.")
            }
            return try await fallbackDownloadService.download(request: request, progressHandler: progressHandler)
        }

        do {
            return try await onlineDownloadService.download(request: request, progressHandler: progressHandler)
        } catch {
            guard allowFallbackToMock,
                  let fallbackDownloadService,
                  shouldFallback(for: error) else {
                throw error
            }
            logger.info("Falling back to mock download for: \(request.source.value)")
            return try await fallbackDownloadService.download(request: request, progressHandler: progressHandler)
        }
    }

    private func shouldFallback(for error: Error) -> Bool {
        guard let downloadError = error as? DownloadError else {
            return false
        }

        switch downloadError {
        case .ytDLPNotFound, .commandExecutionFailed, .outputNotProduced:
            return true
        case .invalidSelection, .outputDirectoryUnavailable, .filenameResolutionFailed, .ffmpegNotFound, .progressParseFailed:
            return false
        }
    }
}
