import Foundation

struct CompositeMediaInspectionService: MediaInspectionServiceProtocol {
    private let urlInspectionService: any MediaInspectionServiceProtocol
    private let localInspectionService: any MediaInspectionServiceProtocol
    private let fallbackInspectionService: (any MediaInspectionServiceProtocol)?
    private let allowFallbackToMock: Bool
    private let logger: any AppLoggerProtocol

    init(
        urlInspectionService: any MediaInspectionServiceProtocol,
        localInspectionService: any MediaInspectionServiceProtocol,
        fallbackInspectionService: (any MediaInspectionServiceProtocol)?,
        allowFallbackToMock: Bool,
        logger: any AppLoggerProtocol
    ) {
        self.urlInspectionService = urlInspectionService
        self.localInspectionService = localInspectionService
        self.fallbackInspectionService = fallbackInspectionService
        self.allowFallbackToMock = allowFallbackToMock
        self.logger = logger
    }

    func inspect(source: MediaSource) async throws -> MediaMetadata {
        let primaryService: any MediaInspectionServiceProtocol
        switch source.type {
        case .url:
            primaryService = urlInspectionService
        case .localFile:
            primaryService = localInspectionService
        }

        do {
            return try await primaryService.inspect(source: source)
        } catch {
            if allowFallbackToMock,
               shouldFallback(for: error),
               let fallbackInspectionService {
                logger.info("Falling back to mock media inspection: \(source.value)")
                return try await fallbackInspectionService.inspect(source: source)
            }
            throw error
        }
    }

    private func shouldFallback(for error: Error) -> Bool {
        guard let inspectionError = error as? MediaInspectionError else {
            return false
        }

        switch inspectionError {
        case let .external(externalError):
            switch externalError {
            case .toolNotFound, .executionFailed, .decodeFailed, .invalidOutput:
                return true
            case .invalidSource, .unsupportedSourceType:
                return false
            }
        case .failed:
            return true
        }
    }
}
