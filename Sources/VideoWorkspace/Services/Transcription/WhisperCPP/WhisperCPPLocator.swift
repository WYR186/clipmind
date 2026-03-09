import Foundation

struct WhisperCPPLocator {
    private let toolLocator: any ExternalToolLocating

    init(toolLocator: any ExternalToolLocating) {
        self.toolLocator = toolLocator
    }

    func locateExecutable(customPath: String?) throws -> String {
        if let customPath,
           !customPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           FileManager.default.isExecutableFile(atPath: customPath) {
            return customPath
        }

        let candidates = ["whisper-cli", "main", "whisper"]
        for candidate in candidates {
            if let path = try? toolLocator.locate(candidate) {
                return path
            }
        }

        throw TranscriptionError.whisperExecutableNotFound
    }
}
