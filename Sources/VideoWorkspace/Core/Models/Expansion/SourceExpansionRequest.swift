import Foundation

public struct SourceExpansionRequest: Hashable, Sendable {
    public let source: ExpandableSource
    public let sourceTypeHint: SourceExpansionKind?
    public let deduplicationPolicy: SourceDeduplicationPolicy
    public let selectionDefault: ExpandedSourceSelectionDefault

    public init(
        source: ExpandableSource,
        sourceTypeHint: SourceExpansionKind? = nil,
        deduplicationPolicy: SourceDeduplicationPolicy = .normalizedURL,
        selectionDefault: ExpandedSourceSelectionDefault = .selectAllValid
    ) {
        self.source = source
        self.sourceTypeHint = sourceTypeHint
        self.deduplicationPolicy = deduplicationPolicy
        self.selectionDefault = selectionDefault
    }
}
