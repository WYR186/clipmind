import Foundation

enum SchemaVersion: Int32, CaseIterable, Sendable {
    case v1 = 1

    static var latest: SchemaVersion {
        .v1
    }
}
