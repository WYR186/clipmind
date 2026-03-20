import Foundation

public enum PreflightSeverity: String, Codable, CaseIterable, Hashable, Sendable {
    case ready
    case needsAttention
    case optional

    var displayText: String {
        switch self {
        case .ready:
            return AppCopy.Preflight.ready
        case .needsAttention:
            return AppCopy.Preflight.needsAttention
        case .optional:
            return AppCopy.Preflight.optional
        }
    }
}

public enum PreflightCheckKey: String, Codable, CaseIterable, Hashable, Sendable {
    case ytDLPAvailable
    case ffmpegAvailable
    case ffprobeAvailable
    case outputDirectoryWritable
    case cacheDirectoryWritable
    case tempDirectoryWritable
    case databaseHealthy
    case keychainHealthy
    case notificationPermission
    case ollamaAvailability
    case lmStudioAvailability
    case providerCacheReadable
    case lastCleanupStatus
}

public struct PreflightIssue: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let key: PreflightCheckKey
    public let severity: PreflightSeverity
    public let title: String
    public let message: String
    public let details: String?
    public let suggestions: [RecoverySuggestion]

    public init(
        id: UUID = UUID(),
        key: PreflightCheckKey,
        severity: PreflightSeverity,
        title: String,
        message: String,
        details: String? = nil,
        suggestions: [RecoverySuggestion] = []
    ) {
        self.id = id
        self.key = key
        self.severity = severity
        self.title = title
        self.message = message
        self.details = details
        self.suggestions = suggestions
    }
}

public struct PreflightCheckResult: Codable, Hashable, Sendable {
    public let checkedAt: Date
    public let issues: [PreflightIssue]

    public init(checkedAt: Date, issues: [PreflightIssue]) {
        self.checkedAt = checkedAt
        self.issues = issues
    }

    public var overallSeverity: PreflightSeverity {
        if issues.contains(where: { $0.severity == .needsAttention }) {
            return .needsAttention
        }
        if issues.contains(where: { $0.severity == .optional }) {
            return .optional
        }
        return .ready
    }

    public var requiresAttentionCount: Int {
        issues.filter { $0.severity == .needsAttention }.count
    }

    public var optionalCount: Int {
        issues.filter { $0.severity == .optional }.count
    }
}

