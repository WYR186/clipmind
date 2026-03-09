import Foundation

public struct ConversionRequest: Sendable {
    public let inputPath: String
    public let outputFormat: String

    public init(inputPath: String, outputFormat: String) {
        self.inputPath = inputPath
        self.outputFormat = outputFormat
    }
}

public struct ConversionResult: Sendable {
    public let outputPath: String

    public init(outputPath: String) {
        self.outputPath = outputPath
    }
}
