import Foundation

struct FFmpegCommandBuilder {
    // TODO: Expand conversion options in a dedicated conversion phase.
    func buildRemuxArguments(inputPath: String, outputPath: String) -> [String] {
        [
            "-y",
            "-i", inputPath,
            "-c", "copy",
            outputPath
        ]
    }
}
