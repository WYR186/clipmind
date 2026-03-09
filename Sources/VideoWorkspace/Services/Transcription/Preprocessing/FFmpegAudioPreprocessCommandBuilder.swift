import Foundation

struct FFmpegAudioPreprocessCommandBuilder {
    func buildWhisperNormalizationArguments(inputPath: String, outputPath: String) -> [String] {
        [
            "-y",
            "-i", inputPath,
            "-vn",
            "-ac", "1",
            "-ar", "16000",
            "-c:a", "pcm_s16le",
            outputPath
        ]
    }

    func buildOpenAIPreprocessArguments(inputPath: String, outputPath: String) -> [String] {
        [
            "-y",
            "-i", inputPath,
            "-vn",
            "-ac", "1",
            "-ar", "16000",
            "-c:a", "aac",
            "-b:a", "128k",
            outputPath
        ]
    }
}
