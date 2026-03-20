import Foundation

struct MockMediaConversionService: MediaConversionServiceProtocol {
    func convert(request: ConversionRequest) async throws -> ConversionResult {
        try await Task.sleep(nanoseconds: 200_000_000)
        let base = URL(fileURLWithPath: request.inputPath).deletingPathExtension().path
        return ConversionResult(outputPath: "\(base).\(request.outputFormat)")
    }
}
