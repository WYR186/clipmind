import Foundation

public struct SchemaMigrationRecord: Codable, Hashable, Sendable {
    public let version: Int
    public let appliedAt: Date

    public init(version: Int, appliedAt: Date) {
        self.version = version
        self.appliedAt = appliedAt
    }
}
