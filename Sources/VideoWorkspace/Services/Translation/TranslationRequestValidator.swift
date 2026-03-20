import Foundation

struct TranslationRequestValidator {
    func validate(_ request: TranslationRequest) throws {
        if request.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TranslationError.sourceTextMissing
        }

        if request.modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TranslationError.invalidRequest(reason: "Model identifier is required.")
        }

        if request.languagePair.targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TranslationError.invalidRequest(reason: "Target language is required.")
        }

        if request.outputFormats.isEmpty {
            throw TranslationError.invalidRequest(reason: "At least one output format is required.")
        }

        if request.mode == .subtitlePreserving,
           request.preserveTimestamps,
           request.sourceSegments.isEmpty {
            throw TranslationError.invalidRequest(reason: "Subtitle-preserving translation requires transcript segments.")
        }
    }
}
