import Foundation

struct AnthropicSummaryMapper {
    func extractText(from response: AnthropicMessageResponse) -> String {
        response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
