import Foundation

protocol ExternalToolLocating: Sendable {
    func locate(_ toolName: String) throws -> String
}

struct ExternalToolLocator: ExternalToolLocating {
    private let environment: [String: String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    func locate(_ toolName: String) throws -> String {
        let searchPaths = candidatePaths(for: toolName)
        for path in searchPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        throw ExternalToolError.toolNotFound(tool: toolName, searchedPaths: searchPaths)
    }

    private func candidatePaths(for toolName: String) -> [String] {
        var paths: [String] = []

        if let pathValue = environment["PATH"] {
            paths += pathValue
                .split(separator: ":")
                .map { String($0) + "/" + toolName }
        }

        paths += [
            "/opt/homebrew/bin/\(toolName)",
            "/usr/local/bin/\(toolName)",
            "/usr/bin/\(toolName)",
            "/bin/\(toolName)"
        ]
        var deduplicated: [String] = []
        var seen = Set<String>()
        for path in paths where !seen.contains(path) {
            seen.insert(path)
            deduplicated.append(path)
        }
        return deduplicated
    }
}
