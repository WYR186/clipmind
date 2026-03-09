import Foundation

struct OpenAISummaryMapper {
    func extractText(from response: OpenAIResponsesResponse) -> String {
        if let direct = response.outputText?.trimmingCharacters(in: .whitespacesAndNewlines), !direct.isEmpty {
            return direct
        }

        let fromNested = response.output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (fromNested?.isEmpty == false) ? fromNested! : ""
    }
}
