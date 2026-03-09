import Foundation

struct SummaryPromptTemplate: Sendable {
    let kind: SummaryPromptTemplateKind
    let title: String
    let body: String

    func render(language: String, length: SummaryLength, mode: SummaryMode) -> String {
        body
            .replacingOccurrences(of: "{{language}}", with: language)
            .replacingOccurrences(of: "{{length}}", with: length.rawValue)
            .replacingOccurrences(of: "{{mode}}", with: mode.rawValue)
    }
}
