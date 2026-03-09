import Foundation

struct FFprobeCommandBuilder {
    func buildInspectArguments(filePath: String) -> [String] {
        [
            "-v", "error",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            "--",
            filePath
        ]
    }
}
