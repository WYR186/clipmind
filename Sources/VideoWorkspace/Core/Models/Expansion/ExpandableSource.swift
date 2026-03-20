import Foundation

public enum ExpandableSource: Hashable, Sendable {
    case singleURL(String)
    case urlTextBlob(String)
    case playlistURL(String)
}
