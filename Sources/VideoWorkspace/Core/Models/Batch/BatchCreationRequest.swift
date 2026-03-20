import Foundation

public struct BatchCreationRequest: Sendable {
    public let title: String?
    public let sourceType: BatchSourceType
    public let sources: [MediaSource]
    public let operationTemplate: BatchOperationTemplate
    public let sourceDescriptor: String?
    public let sourceMetadataJSON: String?

    public init(
        title: String? = nil,
        sourceType: BatchSourceType,
        sources: [MediaSource],
        operationTemplate: BatchOperationTemplate,
        sourceDescriptor: String? = nil,
        sourceMetadataJSON: String? = nil
    ) {
        self.title = title
        self.sourceType = sourceType
        self.sources = sources
        self.operationTemplate = operationTemplate
        self.sourceDescriptor = sourceDescriptor
        self.sourceMetadataJSON = sourceMetadataJSON
    }
}
