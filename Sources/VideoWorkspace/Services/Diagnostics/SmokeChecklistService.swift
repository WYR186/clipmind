import Foundation

actor SmokeChecklistService: SmokeChecklistServiceProtocol {
    private let preflightCheckService: any PreflightCheckServiceProtocol
    private let diagnosticsDirectory: URL
    private let logger: any AppLoggerProtocol
    private var cachedResult: SmokeChecklistResult?

    init(
        preflightCheckService: any PreflightCheckServiceProtocol,
        diagnosticsDirectory: URL,
        logger: any AppLoggerProtocol
    ) {
        self.preflightCheckService = preflightCheckService
        self.diagnosticsDirectory = diagnosticsDirectory
        self.logger = logger
    }

    func latestResult() async -> SmokeChecklistResult? {
        cachedResult
    }

    func runChecklist(force: Bool) async -> SmokeChecklistResult {
        if !force, let cachedResult {
            return cachedResult
        }

        let preflight = await preflightCheckService.runChecks(force: force)
        let items = preflight.issues.map(mapItem(from:))
        let result = SmokeChecklistResult(
            generatedAt: Date(),
            preflightResult: preflight,
            items: items
        )
        cachedResult = result
        logger.info("Smoke checklist completed: pass=\(result.passCount), warning=\(result.warningCount), fail=\(result.failureCount)")
        return result
    }

    func exportChecklistResult(_ result: SmokeChecklistResult?) async throws -> URL {
        let resolvedResult: SmokeChecklistResult
        if let result {
            resolvedResult = result
        } else if let cachedResult {
            resolvedResult = cachedResult
        } else {
            resolvedResult = await runChecklist(force: false)
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: diagnosticsDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let directory = diagnosticsDirectory.appendingPathComponent("smoke-checklist-\(timestamp)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let jsonURL = directory.appendingPathComponent("smoke-checklist.json", isDirectory: false)
        let textURL = directory.appendingPathComponent("smoke-checklist.txt", isDirectory: false)

        let jsonData = try JSONEncoder.pretty.encode(resolvedResult)
        try jsonData.write(to: jsonURL)
        try resolvedResult.summaryText.data(using: .utf8)?.write(to: textURL)

        return directory
    }

    private func mapItem(from issue: PreflightIssue) -> SmokeChecklistItem {
        let status: SmokeChecklistItemStatus
        switch issue.severity {
        case .ready:
            status = .pass
        case .optional:
            status = .warning
        case .needsAttention:
            status = .fail
        }

        return SmokeChecklistItem(
            key: issue.key,
            title: issue.title,
            message: issue.message,
            status: status,
            details: issue.details,
            suggestions: issue.suggestions
        )
    }
}

private extension SmokeChecklistResult {
    var summaryText: String {
        let rows = items.map {
            "- [\($0.status.displayText)] \($0.title): \($0.message)"
        }.joined(separator: "\n")

        return """
        Smoke Checklist
        Generated: \(generatedAt.ISO8601Format())
        Summary: \(summaryLine)

        \(rows)
        """
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

