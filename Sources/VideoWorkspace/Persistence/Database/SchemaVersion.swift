import Foundation

enum SchemaVersion: Int32, CaseIterable, Sendable {
    case v1 = 1
    case v2 = 2
    case v3 = 3
    case v4 = 4

    static var latest: SchemaVersion {
        .v4
    }
}
