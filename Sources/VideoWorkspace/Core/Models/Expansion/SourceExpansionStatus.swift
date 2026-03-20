import Foundation

public enum SourceExpansionKind: String, Codable, CaseIterable, Sendable {
    case singleURL
    case multiURL
    case playlistURL
}

public enum SourceExpansionStatus: String, Codable, CaseIterable, Sendable {
    case ready
    case partial
    case empty
}

public enum SourceDeduplicationPolicy: String, Codable, CaseIterable, Sendable {
    case none
    case normalizedURL
}

public enum ExpandedSourceSelectionDefault: String, Codable, CaseIterable, Sendable {
    case selectAllValid
    case selectNone
}
