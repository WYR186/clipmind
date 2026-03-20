import Foundation

public struct SourceExpansionResult: Hashable, Sendable {
    public let sourceKind: SourceExpansionKind
    public let sourceURL: String?
    public let playlistMetadata: PlaylistMetadata?
    public let status: SourceExpansionStatus
    public var expandedItems: [ExpandedSourceItem]
    public let skippedItems: [ExpandedSourceItem]
    public let diagnostics: String?

    public init(
        sourceKind: SourceExpansionKind,
        sourceURL: String?,
        playlistMetadata: PlaylistMetadata? = nil,
        status: SourceExpansionStatus,
        expandedItems: [ExpandedSourceItem],
        skippedItems: [ExpandedSourceItem],
        diagnostics: String? = nil
    ) {
        self.sourceKind = sourceKind
        self.sourceURL = sourceURL
        self.playlistMetadata = playlistMetadata
        self.status = status
        self.expandedItems = expandedItems
        self.skippedItems = skippedItems
        self.diagnostics = diagnostics
    }

    public var selectedCount: Int {
        expandedItems.filter { $0.isSelected && $0.isValid }.count
    }

    public var validCount: Int {
        expandedItems.filter(\.isValid).count
    }

    public var skippedCount: Int {
        skippedItems.count
    }
}
