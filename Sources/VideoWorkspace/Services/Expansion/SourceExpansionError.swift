import Foundation

enum SourceExpansionError: Error, LocalizedError {
    case invalidInput(reason: String)
    case playlistNotDetected
    case noPlaylistEntries
    case noSelectableItems
    case external(ExternalToolError)
    case decodeFailed(details: String)

    var errorDescription: String? {
        switch self {
        case let .invalidInput(reason):
            return reason
        case .playlistNotDetected:
            return "The provided URL does not resolve to a playlist source."
        case .noPlaylistEntries:
            return "No playlist entries were found in the source."
        case .noSelectableItems:
            return "No valid items could be selected from this source expansion."
        case let .external(error):
            return error.userMessage
        case .decodeFailed:
            return "Failed to decode source expansion payload."
        }
    }

    var diagnostics: String {
        switch self {
        case let .invalidInput(reason):
            return "invalid_input=\(reason)"
        case .playlistNotDetected:
            return "playlist_not_detected"
        case .noPlaylistEntries:
            return "no_playlist_entries"
        case .noSelectableItems:
            return "no_selectable_items"
        case let .external(error):
            return error.diagnostics
        case let .decodeFailed(details):
            return "decode_failed=\(details)"
        }
    }
}

enum ExpandedSourceMapperError: Error, LocalizedError {
    case noSelectedItems

    var errorDescription: String? {
        switch self {
        case .noSelectedItems:
            return "Select at least one valid expanded source item before creating a batch."
        }
    }
}
