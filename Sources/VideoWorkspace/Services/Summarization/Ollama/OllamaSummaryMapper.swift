import Foundation

struct OllamaSummaryMapper {
    func extractText(from response: OllamaChatResponse) -> String {
        response.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
