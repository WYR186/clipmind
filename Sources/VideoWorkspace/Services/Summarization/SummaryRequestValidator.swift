import Foundation

struct SummaryRequestValidator {
    func validate(_ request: SummarizationRequest) throws {
        let summaryRequest = request.summaryRequest

        guard !request.transcript.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummarizationError.transcriptMissing
        }

        if summaryRequest.modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SummarizationError.invalidSummaryRequest(reason: "Model identifier is required.")
        }

        if summaryRequest.outputLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SummarizationError.invalidSummaryRequest(reason: "Output language is required.")
        }
    }
}
