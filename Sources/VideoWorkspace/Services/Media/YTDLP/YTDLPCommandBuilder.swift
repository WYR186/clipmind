import Foundation

struct YTDLPCommandBuilder {
    func buildInspectArguments(url: String) -> [String] {
        [
            "--dump-single-json",
            "--skip-download",
            "--no-warnings",
            "--no-playlist",
            "--",
            url
        ]
    }
}
