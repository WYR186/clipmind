import Foundation

struct MockMediaConversionService: MediaConversionServiceProtocol {
    func convert(request: ConversionRequest) async throws -> ConversionResult {
        // TODO: Replace with a real ffmpeg adapter.
        try await Task.sleep(nanoseconds: 200_000_000)
        return ConversionResult(outputPath: "\(request.inputPath).\(request.outputFormat)")
    }
}
