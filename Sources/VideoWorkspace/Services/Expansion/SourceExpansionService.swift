import Foundation

struct SourceExpansionService: SourceExpansionServiceProtocol {
    private let playlistExpansionService: any PlaylistExpansionServiceProtocol
    private let logger: any AppLoggerProtocol

    init(
        playlistExpansionService: any PlaylistExpansionServiceProtocol,
        logger: any AppLoggerProtocol
    ) {
        self.playlistExpansionService = playlistExpansionService
        self.logger = logger
    }

    func isLikelyPlaylistURL(_ rawURL: String) -> Bool {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let host = components.host?.lowercased()
        else {
            return false
        }

        let queryNames = Set((components.queryItems ?? []).map { $0.name.lowercased() })
        let path = components.path.lowercased()

        if queryNames.contains("list") || queryNames.contains("playlist") {
            return true
        }

        if path.contains("playlist") || path.contains("series") || path.contains("collection") {
            return true
        }

        if host.contains("bilibili.com") {
            if path.contains("medialist") || path.contains("favlist") || path.contains("collection") {
                return true
            }
            if queryNames.contains("sid") || queryNames.contains("series") {
                return true
            }
        }

        return false
    }

    func expand(request: SourceExpansionRequest) async throws -> SourceExpansionResult {
        switch request.source {
        case let .playlistURL(url):
            return try await playlistExpansionService.expandPlaylist(
                url: url,
                deduplicationPolicy: request.deduplicationPolicy,
                selectionDefault: request.selectionDefault
            )
        case let .singleURL(url):
            return try expandURLs(
                inputValues: [url],
                sourceKind: .singleURL,
                sourceURL: url,
                deduplicationPolicy: request.deduplicationPolicy,
                selectionDefault: request.selectionDefault
            )
        case let .urlTextBlob(textBlob):
            let lines = textBlob
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return try expandURLs(
                inputValues: lines,
                sourceKind: .multiURL,
                sourceURL: nil,
                deduplicationPolicy: request.deduplicationPolicy,
                selectionDefault: request.selectionDefault
            )
        }
    }

    private func expandURLs(
        inputValues: [String],
        sourceKind: SourceExpansionKind,
        sourceURL: String?,
        deduplicationPolicy: SourceDeduplicationPolicy,
        selectionDefault: ExpandedSourceSelectionDefault
    ) throws -> SourceExpansionResult {
        guard !inputValues.isEmpty else {
            throw SourceExpansionError.invalidInput(reason: "No source entries were provided")
        }

        var seen: Set<String> = []
        var expandedItems: [ExpandedSourceItem] = []
        var skippedItems: [ExpandedSourceItem] = []

        for (index, rawValue) in inputValues.enumerated() {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard isHTTPURL(trimmed) else {
                skippedItems.append(
                    ExpandedSourceItem(
                        displayTitle: trimmed,
                        sourceURL: nil,
                        originalIndex: index,
                        isSelected: false,
                        isValid: false,
                        skipReason: "Invalid URL format"
                    )
                )
                continue
            }

            if let key = dedupeKey(for: trimmed, policy: deduplicationPolicy), !seen.insert(key).inserted {
                skippedItems.append(
                    ExpandedSourceItem(
                        displayTitle: trimmed,
                        sourceURL: trimmed,
                        originalIndex: index,
                        isSelected: false,
                        isValid: false,
                        skipReason: "Duplicate URL filtered"
                    )
                )
                continue
            }

            expandedItems.append(
                ExpandedSourceItem(
                    displayTitle: trimmed,
                    sourceURL: trimmed,
                    originalIndex: index,
                    isSelected: selectionDefault == .selectAllValid,
                    isValid: true,
                    skipReason: nil
                )
            )
        }

        if expandedItems.isEmpty {
            throw SourceExpansionError.noSelectableItems
        }

        let status: SourceExpansionStatus = skippedItems.isEmpty ? .ready : .partial
        logger.info("Source expansion: kind=\(sourceKind.rawValue) expanded=\(expandedItems.count) skipped=\(skippedItems.count)")

        return SourceExpansionResult(
            sourceKind: sourceKind,
            sourceURL: sourceURL,
            status: status,
            expandedItems: expandedItems,
            skippedItems: skippedItems,
            diagnostics: nil
        )
    }

    private func dedupeKey(for rawURL: String, policy: SourceDeduplicationPolicy) -> String? {
        switch policy {
        case .none:
            return nil
        case .normalizedURL:
            if var components = URLComponents(string: rawURL) {
                components.fragment = nil
                let normalized = components.string ?? rawURL
                return normalized.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
            return rawURL.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
    }

    private func isHTTPURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return ["http", "https"].contains(scheme)
    }
}
