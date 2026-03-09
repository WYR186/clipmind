import Foundation

struct TranscriptionRequestValidator {
    func validate(_ request: TranscriptionRequest) throws {
        guard request.sourceType == .localFile else {
            throw TranscriptionError.unsupportedSourceType(request.sourceType)
        }

        if request.sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TranscriptionError.invalidTranscriptionRequest(reason: "Source path is required.")
        }

        if !FileManager.default.fileExists(atPath: request.sourcePath) {
            throw TranscriptionError.sourceFileMissing(path: request.sourcePath)
        }

        if request.outputKinds.isEmpty {
            throw TranscriptionError.invalidTranscriptionRequest(reason: "At least one transcript output format is required.")
        }

        if request.modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TranscriptionError.invalidTranscriptionRequest(reason: "Model identifier is required.")
        }

        if request.backend == .whisperCPP,
           (request.whisperModelPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            throw TranscriptionError.invalidTranscriptionRequest(reason: "Whisper model path is required for whisper.cpp backend.")
        }
    }
}
