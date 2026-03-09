import Foundation

struct PromptTemplateRegistry {
    private let templates: [SummaryPromptTemplateKind: SummaryPromptTemplate]

    init() {
        templates = [
            .general: SummaryPromptTemplate(
                kind: .general,
                title: "General Summary",
                body: "You are an expert analyst. Produce a {{length}} {{mode}} in {{language}}. Include a clear title, abstract summary, key points, and sections."
            ),
            .studyNotes: SummaryPromptTemplate(
                kind: .studyNotes,
                title: "Study Notes",
                body: "Turn the transcript into study notes in {{language}}. Keep {{length}} detail and focus on exam-relevant concepts, definitions, and checkpoints."
            ),
            .keyPoints: SummaryPromptTemplate(
                kind: .keyPoints,
                title: "Key Points",
                body: "Extract concise key points in {{language}}. The output should be {{length}} and optimized for quick review."
            ),
            .chapterSummary: SummaryPromptTemplate(
                kind: .chapterSummary,
                title: "Chapter Summary",
                body: "Split the transcript into logical chapters and summarize each chapter in {{language}} with {{length}} detail."
            ),
            .timeline: SummaryPromptTemplate(
                kind: .timeline,
                title: "Timeline",
                body: "Build a timeline in {{language}} from the transcript. Include notable moments and short descriptions with {{length}} detail."
            ),
            .bilingual: SummaryPromptTemplate(
                kind: .bilingual,
                title: "Bilingual Summary",
                body: "Produce a bilingual summary in {{language}} and English. Keep {{length}} detail and include key points and section headings."
            )
        ]
    }

    func renderPrompt(for request: SummaryRequest) -> String {
        if let custom = request.customPromptOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }

        let template = templates[request.templateKind] ?? templates[.general]!
        let rendered = template.render(
            language: request.outputLanguage,
            length: request.length,
            mode: request.mode
        )

        let suffix = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if suffix.isEmpty {
            return rendered
        }

        return rendered + "\n\nAdditional constraints:\n" + suffix
    }

    func allTemplates() -> [SummaryPromptTemplateKind: SummaryPromptTemplate] {
        templates
    }
}
