import Foundation

public struct AudioPreprocessResult: Sendable {
    public let inputPath: String
    public let preparedPath: String
    public let usedPreprocessing: Bool
    public let temporaryFiles: [String]

    public init(
        inputPath: String,
        preparedPath: String,
        usedPreprocessing: Bool,
        temporaryFiles: [String]
    ) {
        self.inputPath = inputPath
        self.preparedPath = preparedPath
        self.usedPreprocessing = usedPreprocessing
        self.temporaryFiles = temporaryFiles
    }
}
