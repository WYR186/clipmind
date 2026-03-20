import Foundation

struct SubtitleTranslationMapper {
    func prompt(
        for text: String,
        request: TranslationRequest,
        segmentIndex: Int? = nil,
        totalSegments: Int? = nil
    ) -> String {
        let sourceLang = normalizedSourceLanguage(request.languagePair.sourceLanguage)
        let targetLang = request.languagePair.targetLanguage

        var lines: [String] = []

        // Role & task
        lines.append("You are an expert translator specializing in media transcripts and subtitles.")
        lines.append("Your task: translate the provided text from \(sourceLang) into \(targetLang).")

        // Style guidance
        switch request.style {
        case .faithful:
            lines.append("Translation style: faithful — preserve the original meaning and phrasing as closely as possible.")
        case .natural:
            lines.append("Translation style: natural — produce fluent, idiomatic \(targetLang) that reads naturally to native speakers.")
        case .concise:
            lines.append("Translation style: concise — keep the translation brief and to the point, trimming any redundancy.")
        }

        // Subtitle/timing constraints
        if request.mode == .subtitlePreserving || request.preserveTimestamps {
            lines.append("This is a subtitle segment. Keep the translation concise and timed to match the original speech rhythm.")
            lines.append("Avoid paraphrasing that would significantly lengthen or shorten the text.")
        }

        // Terminology
        if request.preserveTerminology {
            lines.append("Preserve proper nouns, technical terms, brand names, and named entities in their original or standard \(targetLang) form.")
        }

        // Bilingual context
        if request.bilingualOutputEnabled || request.mode == .bilingual {
            lines.append("The translation will be shown alongside the original text.")
        }

        // Segment context
        if let idx = segmentIndex, let total = totalSegments {
            lines.append("Segment \(idx + 1) of \(total) — maintain consistency with surrounding segments.")
        }

        // Output constraint
        lines.append("Output ONLY the translated text. Do not include explanations, notes, or the original text.")

        return lines.joined(separator: "\n") + "\n\nText to translate:\n\(text)"
    }

    func sourceSegments(for request: TranslationRequest) -> [TranscriptSegment] {
        if !request.sourceSegments.isEmpty {
            return request.sourceSegments
        }

        let lines = request.sourceText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.isEmpty {
            return [TranscriptSegment(index: 0, startSeconds: 0, endSeconds: 3, text: request.sourceText)]
        }

        return lines.enumerated().map { index, line in
            TranscriptSegment(
                index: index,
                startSeconds: Double(index * 3),
                endSeconds: Double(index * 3 + 2),
                text: line
            )
        }
    }

    func mergeTranslatedSegments(_ segments: [TranslationSegment]) -> String {
        segments
            .sorted { $0.index < $1.index }
            .map(\.translatedText)
            .joined(separator: "\n")
    }

    func makeBilingualText(sourceText: String, translatedText: String) -> String {
        let sourceLines = sourceText.components(separatedBy: .newlines)
        let translatedLines = translatedText.components(separatedBy: .newlines)
        let count = max(sourceLines.count, translatedLines.count)

        return (0..<count).map { index in
            let sourceLine = index < sourceLines.count ? sourceLines[index] : ""
            let translatedLine = index < translatedLines.count ? translatedLines[index] : ""
            return "- \(sourceLine)\n  \(translatedLine)"
        }.joined(separator: "\n")
    }

    func makeBilingualText(from translatedSegments: [TranslationSegment]) -> String {
        translatedSegments
            .sorted { $0.index < $1.index }
            .map { segment in
                "- \(segment.sourceText)\n  \(segment.translatedText)"
            }
            .joined(separator: "\n")
    }

    func subtitleSegments(from translatedSegments: [TranslationSegment]) -> [TranscriptSegment] {
        translatedSegments
            .sorted { $0.index < $1.index }
            .enumerated()
            .map { offset, segment in
                let defaultStart = Double(offset * 3)
                let start = segment.startSeconds ?? defaultStart
                let end = segment.endSeconds ?? (start + 2)
                return TranscriptSegment(
                    index: offset,
                    startSeconds: start,
                    endSeconds: end,
                    text: segment.translatedText
                )
            }
    }

    private func normalizedSourceLanguage(_ sourceLanguage: String) -> String {
        let trimmed = sourceLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "auto-detected language" : trimmed
    }
}
