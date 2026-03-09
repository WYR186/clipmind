import Foundation

struct DownloadProgressEvent: Sendable {
    let progress: TaskProgress?
    let resolvedOutputPath: String?
}

struct DownloadProgressParser {
    func parse(line: String) -> DownloadProgressEvent? {
        if let percent = parsePercent(line: line) {
            return DownloadProgressEvent(
                progress: TaskProgressFactory.step(percent / 100.0, description: "Downloading \(Int(percent))%"),
                resolvedOutputPath: nil
            )
        }

        if let path = parseDestination(line: line) {
            return DownloadProgressEvent(
                progress: TaskProgressFactory.step(0.05, description: "Preparing output"),
                resolvedOutputPath: path
            )
        }

        return nil
    }

    private func parsePercent(line: String) -> Double? {
        guard line.contains("[download]") else { return nil }
        let pattern = #"\[download\]\s+([0-9]+(?:\.[0-9]+)?)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: nsRange),
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(line[valueRange])
    }

    private func parseDestination(line: String) -> String? {
        if let range = line.range(of: "Destination: ") {
            return String(line[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }

        if let range = line.range(of: "Merging formats into \"") {
            let suffix = line[range.upperBound...]
            if let quoteEnd = suffix.firstIndex(of: "\"") {
                return String(suffix[..<quoteEnd])
            }
        }

        return nil
    }
}
