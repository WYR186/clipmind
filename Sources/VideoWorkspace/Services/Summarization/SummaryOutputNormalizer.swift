import Foundation

struct SummaryOutputNormalizer {
    func normalize(text: String, mode: SummaryMode) throws -> StructuredSummaryPayload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SummarizationError.normalizationFailed(details: "empty summary text")
        }

        if let jsonPayload = tryDecodeStructuredJSON(from: trimmed) {
            return jsonPayload
        }

        let lines = trimmed
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let title = lines.first?.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

        let keyPoints = lines
            .filter { $0.hasPrefix("-") || $0.hasPrefix("*") || $0.range(of: #"^[0-9]+\."#, options: .regularExpression) != nil }
            .map { line in
                line
                    .replacingOccurrences(of: #"^[-*]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^[0-9]+\.\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

        let sections = parseSections(from: lines)
        let abstractSummary = sections.first?.content ?? lines.prefix(3).joined(separator: " ")

        return StructuredSummaryPayload(
            title: title,
            abstractSummary: abstractSummary,
            keyPoints: keyPoints,
            chapters: mode == .chapters ? sections.map { SummaryChapter(title: $0.title, summary: $0.content) } : [],
            sections: sections,
            timeline: parseTimeline(from: lines),
            actionItems: parseActionItems(from: lines),
            quotes: parseQuotes(from: lines)
        )
    }

    func toMarkdown(from payload: StructuredSummaryPayload) -> String {
        var parts: [String] = []
        if let title = payload.title, !title.isEmpty {
            parts.append("# \(title)")
        }
        if let abstractSummary = payload.abstractSummary, !abstractSummary.isEmpty {
            parts.append("## Abstract\n\(abstractSummary)")
        }
        if !payload.keyPoints.isEmpty {
            parts.append("## Key Points\n" + payload.keyPoints.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !payload.chapters.isEmpty {
            let block = payload.chapters.map { "### \($0.title)\n\($0.summary)" }.joined(separator: "\n\n")
            parts.append("## Chapters\n\(block)")
        }
        if !payload.timeline.isEmpty {
            let block = payload.timeline.map { entry in
                if let ts = entry.timestampSeconds {
                    return "- [\(Int(ts))s] \(entry.text)"
                }
                return "- \(entry.text)"
            }.joined(separator: "\n")
            parts.append("## Timeline\n\(block)")
        }
        if !payload.actionItems.isEmpty {
            parts.append("## Action Items\n" + payload.actionItems.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !payload.quotes.isEmpty {
            parts.append("## Quotes\n" + payload.quotes.map { "> \($0)" }.joined(separator: "\n"))
        }

        return parts.joined(separator: "\n\n")
    }

    func toPlainText(from payload: StructuredSummaryPayload) -> String {
        var lines: [String] = []
        if let title = payload.title, !title.isEmpty {
            lines.append(title)
        }
        if let abstractSummary = payload.abstractSummary, !abstractSummary.isEmpty {
            lines.append(abstractSummary)
        }
        if !payload.keyPoints.isEmpty {
            lines.append("Key Points:")
            lines.append(contentsOf: payload.keyPoints.map { "- \($0)" })
        }
        if !payload.chapters.isEmpty {
            lines.append("Chapters:")
            lines.append(contentsOf: payload.chapters.map { "- \($0.title): \($0.summary)" })
        }
        return lines.joined(separator: "\n")
    }

    private func tryDecodeStructuredJSON(from text: String) -> StructuredSummaryPayload? {
        guard text.first == "{" || text.first == "[" else { return nil }
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let title = object["title"] as? String
        let abstractSummary = (object["abstractSummary"] as? String) ?? (object["abstract_summary"] as? String)
        let keyPoints = (object["keyPoints"] as? [String]) ?? (object["key_points"] as? [String]) ?? []
        let sections = parseSectionsFromJSON(object["sections"])
        let chapters = parseChaptersFromJSON(object["chapters"])
        let timeline = parseTimelineFromJSON(object["timeline"])
        let actionItems = (object["actionItems"] as? [String]) ?? (object["action_items"] as? [String]) ?? []
        let quotes = (object["quotes"] as? [String]) ?? []

        return StructuredSummaryPayload(
            title: title,
            abstractSummary: abstractSummary,
            keyPoints: keyPoints,
            chapters: chapters,
            sections: sections,
            timeline: timeline,
            actionItems: actionItems,
            quotes: quotes
        )
    }

    private func parseSectionsFromJSON(_ value: Any?) -> [SummarySection] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { item in
            guard let title = item["title"] as? String,
                  let content = item["content"] as? String else {
                return nil
            }
            return SummarySection(title: title, content: content)
        }
    }

    private func parseChaptersFromJSON(_ value: Any?) -> [SummaryChapter] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { item in
            guard let title = item["title"] as? String,
                  let summary = item["summary"] as? String else {
                return nil
            }
            return SummaryChapter(
                title: title,
                startSeconds: item["startSeconds"] as? Double,
                endSeconds: item["endSeconds"] as? Double,
                summary: summary
            )
        }
    }

    private func parseTimelineFromJSON(_ value: Any?) -> [TimelineEntry] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { item in
            guard let text = item["text"] as? String else { return nil }
            return TimelineEntry(timestampSeconds: item["timestampSeconds"] as? Double, text: text)
        }
    }

    private func parseSections(from lines: [String]) -> [SummarySection] {
        var sections: [SummarySection] = []
        var currentTitle = "Section"
        var buffer: [String] = []

        for line in lines {
            if line.hasPrefix("#") {
                if !buffer.isEmpty {
                    sections.append(SummarySection(title: currentTitle, content: buffer.joined(separator: " ")))
                    buffer.removeAll(keepingCapacity: true)
                }
                currentTitle = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            } else {
                buffer.append(line)
            }
        }

        if !buffer.isEmpty {
            sections.append(SummarySection(title: currentTitle, content: buffer.joined(separator: " ")))
        }

        return sections.isEmpty ? [SummarySection(title: "Summary", content: lines.joined(separator: " "))] : sections
    }

    private func parseTimeline(from lines: [String]) -> [TimelineEntry] {
        lines.compactMap { line in
            guard line.range(of: #"\b[0-9]{1,2}:[0-9]{2}\b"#, options: .regularExpression) != nil else {
                return nil
            }
            return TimelineEntry(text: line)
        }
    }

    private func parseActionItems(from lines: [String]) -> [String] {
        lines.filter {
            $0.lowercased().contains("action") ||
            $0.lowercased().contains("todo") ||
            $0.lowercased().contains("next step")
        }
    }

    private func parseQuotes(from lines: [String]) -> [String] {
        lines.filter { $0.hasPrefix("\"") || $0.hasPrefix("'") || $0.hasPrefix(">") }
    }
}
