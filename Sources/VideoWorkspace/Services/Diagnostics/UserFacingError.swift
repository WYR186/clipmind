import Foundation

public struct UserFacingError: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String
    public let code: String
    public let service: String
    public let diagnostics: String?
    public let suggestions: [RecoverySuggestion]

    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        code: String,
        service: String,
        diagnostics: String? = nil,
        suggestions: [RecoverySuggestion] = []
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.code = code
        self.service = service
        self.diagnostics = diagnostics
        self.suggestions = suggestions
    }
}
