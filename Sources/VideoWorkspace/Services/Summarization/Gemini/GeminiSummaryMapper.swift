import Foundation

struct GeminiSummaryMapper {
    func extractText(from response: GeminiGenerateContentResponse) -> String {
        response.candidates?
            .first?
            .content?
            .parts?
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
