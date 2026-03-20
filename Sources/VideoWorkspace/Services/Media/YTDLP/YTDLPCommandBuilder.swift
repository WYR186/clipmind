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

    func buildPlaylistInspectArguments(url: String) -> [String] {
        [
            "--dump-single-json",
            "--skip-download",
            "--no-warnings",
            "--yes-playlist",
            "--ignore-errors",
            "--",
            url
        ]
    }
}
