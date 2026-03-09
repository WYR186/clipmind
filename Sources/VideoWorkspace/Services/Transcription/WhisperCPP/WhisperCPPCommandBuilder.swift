import Foundation

struct WhisperCPPCommandBuilder {
    func buildArguments(
        request: TranscriptionRequest,
        inputAudioPath: String,
        outputBasePath: String
    ) throws -> [String] {
        guard let modelPath = request.whisperModelPath,
              !modelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionError.whisperModelNotFound(path: "")
        }

        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw TranscriptionError.whisperModelNotFound(path: modelPath)
        }

        var args: [String] = [
            "-m", modelPath,
            "-f", inputAudioPath,
            "-of", outputBasePath,
            "-otxt"
        ]

        if request.outputKinds.contains(.srt) {
            args.append("-osrt")
        }

        if request.outputKinds.contains(.vtt) {
            args.append("-ovtt")
        }

        if let language = request.languageHint?.trimmingCharacters(in: .whitespacesAndNewlines), !language.isEmpty {
            args += ["-l", language]
        }

        if let prompt = request.promptHint?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty {
            args += ["--prompt", prompt]
        }

        if let temperature = request.temperature {
            args += ["--temperature", String(temperature)]
        }

        return args
    }
}
