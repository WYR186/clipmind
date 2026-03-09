import Foundation

enum MediaInspectionError: Error, Sendable {
    case external(ExternalToolError)
    case failed(reason: String)
}

extension MediaInspectionError {
    var userMessage: String {
        switch self {
        case let .external(external):
            return external.userMessage
        case let .failed(reason):
            return reason
        }
    }

    var diagnostics: String {
        switch self {
        case let .external(external):
            return external.diagnostics
        case let .failed(reason):
            return reason
        }
    }
}
