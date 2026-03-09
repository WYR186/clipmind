import Foundation

struct SummaryAggregationService {
    private let normalizer: SummaryOutputNormalizer

    init(normalizer: SummaryOutputNormalizer = SummaryOutputNormalizer()) {
        self.normalizer = normalizer
    }

    func combineChunkSummaries(_ summaries: [String]) throws -> String {
        let normalized = summaries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalized.isEmpty else {
            throw SummarizationError.aggregationFailed(details: "No chunk summaries to aggregate")
        }

        return normalized.enumerated().map { index, item in
            "Chunk \(index + 1):\n\(item)"
        }.joined(separator: "\n\n")
    }

    func mergeStructuredPayloads(_ payloads: [StructuredSummaryPayload]) -> StructuredSummaryPayload {
        guard !payloads.isEmpty else {
            return StructuredSummaryPayload()
        }

        let title = payloads.compactMap(\.title).first
        let abstractSummary = payloads.compactMap(\.abstractSummary).joined(separator: " ")
        let keyPoints = Array(Set(payloads.flatMap(\.keyPoints))).sorted()
        let chapters = payloads.flatMap(\.chapters)
        let sections = payloads.flatMap(\.sections)
        let timeline = payloads.flatMap(\.timeline)
        let actionItems = Array(Set(payloads.flatMap(\.actionItems))).sorted()
        let quotes = Array(Set(payloads.flatMap(\.quotes))).sorted()

        return StructuredSummaryPayload(
            title: title,
            abstractSummary: abstractSummary.isEmpty ? nil : abstractSummary,
            keyPoints: keyPoints,
            chapters: chapters,
            sections: sections,
            timeline: timeline,
            actionItems: actionItems,
            quotes: quotes
        )
    }

    func finalizeResult(
        taskID: UUID,
        request: SummaryRequest,
        combinedText: String,
        structuredPayloads: [StructuredSummaryPayload],
        diagnostics: String?
    ) -> SummaryResult {
        let merged = mergeStructuredPayloads(structuredPayloads)
        let markdown = normalizer.toMarkdown(from: merged)
        let plainText = normalizer.toPlainText(from: merged)

        return SummaryResult(
            taskID: taskID,
            provider: request.provider,
            modelID: request.modelID,
            mode: request.mode,
            length: request.length,
            content: request.outputFormat == .plainText ? plainText : markdown,
            structured: merged,
            markdown: markdown,
            plainText: plainText,
            artifacts: [],
            templateKind: request.templateKind,
            outputLanguage: request.outputLanguage,
            diagnostics: diagnostics
        )
    }
}
