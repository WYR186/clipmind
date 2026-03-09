import XCTest
@testable import VideoWorkspace

final class PromptTemplateRegistryTests: XCTestCase {
    func testRenderDefaultTemplate() {
        let registry = PromptTemplateRegistry()
        let request = SummaryRequest(
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .keyPoints,
            length: .short,
            outputLanguage: "zh",
            prompt: "Focus on practical tips",
            templateKind: .studyNotes
        )

        let rendered = registry.renderPrompt(for: request)
        XCTAssertTrue(rendered.contains("zh"))
        XCTAssertTrue(rendered.contains("Additional constraints"))
    }

    func testCustomPromptOverrideWins() {
        let registry = PromptTemplateRegistry()
        let request = SummaryRequest(
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .abstractSummary,
            length: .medium,
            outputLanguage: "en",
            prompt: "",
            templateKind: .general,
            customPromptOverride: "Use strict JSON only"
        )

        let rendered = registry.renderPrompt(for: request)
        XCTAssertEqual(rendered, "Use strict JSON only")
    }
}
