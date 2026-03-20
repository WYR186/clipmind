import Foundation

public struct PlaylistExpansionPreview: Hashable, Sendable {
    public let metadata: PlaylistMetadata
    public var items: [ExpandedSourceItem]
    public let skippedItems: [ExpandedSourceItem]

    public init(metadata: PlaylistMetadata, items: [ExpandedSourceItem], skippedItems: [ExpandedSourceItem]) {
        self.metadata = metadata
        self.items = items
        self.skippedItems = skippedItems
    }

    public var selectedCount: Int {
        items.filter { $0.isSelected && $0.isValid }.count
    }

    public var validCount: Int {
        items.filter(\.isValid).count
    }

    public var skippedCount: Int {
        skippedItems.count
    }
}
