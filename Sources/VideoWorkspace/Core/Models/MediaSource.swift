import Foundation

public struct MediaSource: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let type: SourceType
    public let value: String

    public init(id: UUID = UUID(), type: SourceType, value: String) {
        self.id = id
        self.type = type
        self.value = value
    }
}
