import Foundation

public struct ExpandedSourceItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var displayTitle: String
    public var sourceURL: String?
    public let originalIndex: Int
    public var durationSeconds: Int?
    public var thumbnailURL: String?
    public var isSelected: Bool
    public var isValid: Bool
    public var skipReason: String?
    public var availability: String?

    public init(
        id: UUID = UUID(),
        displayTitle: String,
        sourceURL: String?,
        originalIndex: Int,
        durationSeconds: Int? = nil,
        thumbnailURL: String? = nil,
        isSelected: Bool = true,
        isValid: Bool = true,
        skipReason: String? = nil,
        availability: String? = nil
    ) {
        self.id = id
        self.displayTitle = displayTitle
        self.sourceURL = sourceURL
        self.originalIndex = max(0, originalIndex)
        self.durationSeconds = durationSeconds
        self.thumbnailURL = thumbnailURL
        self.isSelected = isSelected
        self.isValid = isValid
        self.skipReason = skipReason
        self.availability = availability
    }
}
