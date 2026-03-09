import Foundation

public struct ProviderCapability: Codable, Hashable, Sendable {
    public let supportsTranscription: Bool
    public let supportsSummarization: Bool
    public let supportsStreaming: Bool
    public let supportsStructuredOutput: Bool
    public let isLocalProvider: Bool
    public let capabilityTags: [ModelCapabilityTag]

    public init(
        supportsTranscription: Bool,
        supportsSummarization: Bool,
        supportsStreaming: Bool,
        supportsStructuredOutput: Bool = false,
        isLocalProvider: Bool = false,
        capabilityTags: [ModelCapabilityTag] = []
    ) {
        self.supportsTranscription = supportsTranscription
        self.supportsSummarization = supportsSummarization
        self.supportsStreaming = supportsStreaming
        self.supportsStructuredOutput = supportsStructuredOutput
        self.isLocalProvider = isLocalProvider
        self.capabilityTags = capabilityTags
    }
}

public struct ModelDescriptor: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let contextWindow: Int
    public let capabilities: ProviderCapability
    public let tags: [ModelCapabilityTag]

    public init(
        id: String,
        displayName: String,
        contextWindow: Int,
        capabilities: ProviderCapability,
        tags: [ModelCapabilityTag] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.contextWindow = contextWindow
        self.capabilities = capabilities
        self.tags = tags
    }
}
