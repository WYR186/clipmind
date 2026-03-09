import Foundation

public protocol MediaInspectionServiceProtocol: Sendable {
    func inspect(source: MediaSource) async throws -> MediaMetadata
}

public protocol MediaDownloadServiceProtocol: Sendable {
    func download(
        request: MediaDownloadRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> MediaDownloadResult
}

public extension MediaDownloadServiceProtocol {
    func download(request: MediaDownloadRequest) async throws -> MediaDownloadResult {
        try await download(request: request, progressHandler: nil)
    }
}

public protocol MediaConversionServiceProtocol: Sendable {
    func convert(request: ConversionRequest) async throws -> ConversionResult
}
