import Foundation

public enum SummaryPromptTemplateKind: String, Codable, CaseIterable, Sendable {
    case general
    case studyNotes
    case keyPoints
    case chapterSummary
    case timeline
    case bilingual
}
