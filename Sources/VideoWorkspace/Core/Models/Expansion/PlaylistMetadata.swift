import Foundation

public struct PlaylistMetadata: Codable, Hashable, Sendable {
    public let title: String
    public let sourceURL: String
    public let entryCount: Int
    public let extractor: String?
    public let thumbnailURL: String?

    public init(
        title: String,
        sourceURL: String,
        entryCount: Int,
        extractor: String?,
        thumbnailURL: String?
    ) {
        self.title = title
        self.sourceURL = sourceURL
        self.entryCount = max(0, entryCount)
        self.extractor = extractor
        self.thumbnailURL = thumbnailURL
    }
}
