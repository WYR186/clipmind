import Foundation

// MARK: - Conversion quality

public enum ConversionQuality: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high
    case lossless

    public var audioKbps: Int {
        switch self {
        case .low: return 96
        case .medium: return 192
        case .high: return 320
        case .lossless: return 0
        }
    }

    public var videoCRF: Int {
        switch self {
        case .low: return 32
        case .medium: return 23
        case .high: return 18
        case .lossless: return 0
        }
    }
}

// MARK: - Conversion request

public struct ConversionRequest: Sendable {
    public let inputPath: String
    public let outputFormat: String
    public let quality: ConversionQuality
    public let operation: ConversionOperation
    /// Optional trim start in seconds.
    public let trimStart: Double?
    /// Optional trim duration in seconds. Ignored if trimStart is nil.
    public let trimDuration: Double?
    /// Maximum video width for videoConvert operations.
    public let maxWidth: Int?
    /// Maximum video height for videoConvert operations.
    public let maxHeight: Int?

    public enum ConversionOperation: String, Sendable {
        case remux          // copy streams, change container
        case audioExtract   // demux audio track
        case videoConvert   // re-encode video + audio
        case trim           // cut start/end (stream copy)
        case thumbnail      // extract single frame
    }

    public init(
        inputPath: String,
        outputFormat: String,
        quality: ConversionQuality = .medium,
        operation: ConversionOperation = .audioExtract,
        trimStart: Double? = nil,
        trimDuration: Double? = nil,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil
    ) {
        self.inputPath = inputPath
        self.outputFormat = outputFormat
        self.quality = quality
        self.operation = operation
        self.trimStart = trimStart
        self.trimDuration = trimDuration
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }
}

// MARK: - Conversion result

public struct ConversionResult: Sendable {
    public let outputPath: String

    public init(outputPath: String) {
        self.outputPath = outputPath
    }
}
