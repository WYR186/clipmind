import Foundation

public struct ProviderCacheEntry: Codable, Hashable, Sendable {
    public let provider: ProviderType
    public let models: [ModelDescriptor]
    public let updatedAt: Date
    public let validityMarker: String

    public init(
        provider: ProviderType,
        models: [ModelDescriptor],
        updatedAt: Date = Date(),
        validityMarker: String = "fresh"
    ) {
        self.provider = provider
        self.models = models
        self.updatedAt = updatedAt
        self.validityMarker = validityMarker
    }

    public var isValid: Bool {
        validityMarker == "fresh"
    }
}
