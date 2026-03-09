import Foundation

public enum AppServiceError: Error, Sendable {
    case invalidSource
    case inspectionUnavailable
    case providerUnavailable
    case modelUnavailable
    case transcriptionFailed
    case summarizationFailed
}
