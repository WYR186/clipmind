import Foundation

public enum SmokeChecklistItemStatus: String, Codable, Hashable, Sendable {
    case pass
    case warning
    case fail

    var displayText: String {
        switch self {
        case .pass:
            return "Pass"
        case .warning:
            return "Warning"
        case .fail:
            return "Fail"
        }
    }
}

public struct SmokeChecklistItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let key: PreflightCheckKey
    public let title: String
    public let message: String
    public let status: SmokeChecklistItemStatus
    public let details: String?
    public let suggestions: [RecoverySuggestion]

    public init(
        id: UUID = UUID(),
        key: PreflightCheckKey,
        title: String,
        message: String,
        status: SmokeChecklistItemStatus,
        details: String? = nil,
        suggestions: [RecoverySuggestion] = []
    ) {
        self.id = id
        self.key = key
        self.title = title
        self.message = message
        self.status = status
        self.details = details
        self.suggestions = suggestions
    }
}

public struct SmokeChecklistResult: Codable, Hashable, Sendable {
    public let generatedAt: Date
    public let preflightResult: PreflightCheckResult
    public let items: [SmokeChecklistItem]

    public init(
        generatedAt: Date,
        preflightResult: PreflightCheckResult,
        items: [SmokeChecklistItem]
    ) {
        self.generatedAt = generatedAt
        self.preflightResult = preflightResult
        self.items = items
    }

    public var failureCount: Int {
        items.filter { $0.status == .fail }.count
    }

    public var warningCount: Int {
        items.filter { $0.status == .warning }.count
    }

    public var passCount: Int {
        items.filter { $0.status == .pass }.count
    }

    public var isAcceptable: Bool {
        failureCount == 0
    }

    public var isAllGreen: Bool {
        failureCount == 0 && warningCount == 0
    }

    public var summaryLine: String {
        if isAllGreen {
            return "All checklist items passed."
        }
        if isAcceptable {
            return "Checklist acceptable with \(warningCount) warning(s)."
        }
        return "Checklist has \(failureCount) failure(s) and \(warningCount) warning(s)."
    }
}

