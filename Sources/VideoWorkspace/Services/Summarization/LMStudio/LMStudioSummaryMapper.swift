import Foundation

struct LMStudioSummaryMapper {
    func extractText(from response: LMStudioChatResponse) -> String {
        response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
