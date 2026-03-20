import Foundation

struct PlaylistExpansionService: PlaylistExpansionServiceProtocol {
    private let commandBuilder: YTDLPCommandBuilder
    private let commandExecutor: any CommandExecuting
    private let toolLocator: any ExternalToolLocating
    private let logger: any AppLoggerProtocol

    init(
        commandBuilder: YTDLPCommandBuilder = YTDLPCommandBuilder(),
        commandExecutor: any CommandExecuting,
        toolLocator: any ExternalToolLocating,
        logger: any AppLoggerProtocol
    ) {
        self.commandBuilder = commandBuilder
        self.commandExecutor = commandExecutor
        self.toolLocator = toolLocator
        self.logger = logger
    }

    func expandPlaylist(
        url: String,
        deduplicationPolicy: SourceDeduplicationPolicy,
        selectionDefault: ExpandedSourceSelectionDefault
    ) async throws -> SourceExpansionResult {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedURL = URL(string: trimmedURL),
              let scheme = parsedURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            throw SourceExpansionError.invalidInput(reason: "Invalid playlist URL format")
        }

        do {
            let executablePath = try toolLocator.locate("yt-dlp")
            let arguments = commandBuilder.buildPlaylistInspectArguments(url: trimmedURL)
            let result = try await commandExecutor.execute(executable: executablePath, arguments: arguments)

            if result.exitCode != 0 {
                throw SourceExpansionError.external(
                    .executionFailed(
                        tool: "yt-dlp",
                        diagnostics: makeDiagnostics(from: result)
                    )
                )
            }

            let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stdout.isEmpty else {
                throw SourceExpansionError.external(
                    .invalidOutput(
                        tool: "yt-dlp",
                        diagnostics: makeDiagnostics(from: result)
                    )
                )
            }

            let payload: YTDLPJSONModels.PlaylistRoot
            do {
                payload = try JSONDecoder().decode(YTDLPJSONModels.PlaylistRoot.self, from: Data(stdout.utf8))
            } catch {
                throw SourceExpansionError.decodeFailed(details: makeDiagnostics(from: result).stdoutSnippet)
            }

            guard payload.hasPlaylistShape else {
                throw SourceExpansionError.playlistNotDetected
            }

            let mapped = mapPlaylistPayload(
                sourceURL: trimmedURL,
                parsedSourceURL: parsedURL,
                payload: payload,
                deduplicationPolicy: deduplicationPolicy,
                selectionDefault: selectionDefault
            )

            if mapped.expandedItems.isEmpty, mapped.skippedItems.isEmpty {
                throw SourceExpansionError.noPlaylistEntries
            }

            logger.info("Playlist expansion succeeded: source=\(trimmedURL) expanded=\(mapped.expandedItems.count) skipped=\(mapped.skippedItems.count)")
            return mapped
        } catch let error as SourceExpansionError {
            logger.error("Playlist expansion failed: \(error.diagnostics)")
            throw error
        } catch let error as ExternalToolError {
            let wrapped = SourceExpansionError.external(error)
            logger.error("Playlist expansion failed: \(wrapped.diagnostics)")
            throw wrapped
        } catch {
            let wrapped = SourceExpansionError.decodeFailed(details: error.localizedDescription)
            logger.error("Playlist expansion failed: \(wrapped.diagnostics)")
            throw wrapped
        }
    }

    private func mapPlaylistPayload(
        sourceURL: String,
        parsedSourceURL: URL,
        payload: YTDLPJSONModels.PlaylistRoot,
        deduplicationPolicy: SourceDeduplicationPolicy,
        selectionDefault: ExpandedSourceSelectionDefault
    ) -> SourceExpansionResult {
        var expandedItems: [ExpandedSourceItem] = []
        var skippedItems: [ExpandedSourceItem] = []
        var seen: Set<String> = []

        let entries = payload.entries ?? []
        for (index, optionalEntry) in entries.enumerated() {
            guard let entry = optionalEntry else {
                skippedItems.append(
                    ExpandedSourceItem(
                        displayTitle: "Entry #\(index + 1)",
                        sourceURL: nil,
                        originalIndex: index,
                        isSelected: false,
                        isValid: false,
                        skipReason: "Entry is unavailable"
                    )
                )
                continue
            }

            let availability = normalizedAvailability(entry.availability)
            if let availability, availability != "available" {
                skippedItems.append(
                    ExpandedSourceItem(
                        displayTitle: entry.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Entry #\(index + 1)",
                        sourceURL: resolveEntryURL(entry: entry, sourceURL: parsedSourceURL),
                        originalIndex: resolvedOriginalIndex(for: entry, fallback: index),
                        durationSeconds: entry.duration.map { Int($0.rounded()) },
                        thumbnailURL: entry.thumbnail,
                        isSelected: false,
                        isValid: false,
                        skipReason: "Unavailable entry (\(availability))",
                        availability: availability
                    )
                )
                continue
            }

            guard let resolvedURL = resolveEntryURL(entry: entry, sourceURL: parsedSourceURL) else {
                skippedItems.append(
                    ExpandedSourceItem(
                        displayTitle: entry.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Entry #\(index + 1)",
                        sourceURL: nil,
                        originalIndex: resolvedOriginalIndex(for: entry, fallback: index),
                        durationSeconds: entry.duration.map { Int($0.rounded()) },
                        thumbnailURL: entry.thumbnail,
                        isSelected: false,
                        isValid: false,
                        skipReason: "Missing playable URL"
                    )
                )
                continue
            }

            let dedupeKey = dedupeKey(for: resolvedURL, policy: deduplicationPolicy)
            if let dedupeKey, !seen.insert(dedupeKey).inserted {
                skippedItems.append(
                    ExpandedSourceItem(
                        displayTitle: entry.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Entry #\(index + 1)",
                        sourceURL: resolvedURL,
                        originalIndex: resolvedOriginalIndex(for: entry, fallback: index),
                        durationSeconds: entry.duration.map { Int($0.rounded()) },
                        thumbnailURL: entry.thumbnail,
                        isSelected: false,
                        isValid: false,
                        skipReason: "Duplicate entry filtered"
                    )
                )
                continue
            }

            let selectedByDefault = selectionDefault == .selectAllValid
            expandedItems.append(
                ExpandedSourceItem(
                    displayTitle: entry.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Entry #\(index + 1)",
                    sourceURL: resolvedURL,
                    originalIndex: resolvedOriginalIndex(for: entry, fallback: index),
                    durationSeconds: entry.duration.map { Int($0.rounded()) },
                    thumbnailURL: entry.thumbnail,
                    isSelected: selectedByDefault,
                    isValid: true,
                    skipReason: nil,
                    availability: availability
                )
            )
        }

        let playlistMetadata = PlaylistMetadata(
            title: payload.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Playlist",
            sourceURL: sourceURL,
            entryCount: payload.playlistCount ?? (expandedItems.count + skippedItems.count),
            extractor: payload.extractor ?? payload.extractorKey,
            thumbnailURL: payload.thumbnail
        )

        let status: SourceExpansionStatus
        if expandedItems.isEmpty {
            status = .empty
        } else if skippedItems.isEmpty {
            status = .ready
        } else {
            status = .partial
        }

        return SourceExpansionResult(
            sourceKind: .playlistURL,
            sourceURL: sourceURL,
            playlistMetadata: playlistMetadata,
            status: status,
            expandedItems: expandedItems,
            skippedItems: skippedItems,
            diagnostics: nil
        )
    }

    private func resolveEntryURL(entry: YTDLPJSONModels.PlaylistEntry, sourceURL: URL) -> String? {
        if let webpageURL = entry.webpageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           isHTTPURL(webpageURL) {
            return webpageURL
        }

        guard let rawURL = entry.url?.trimmingCharacters(in: .whitespacesAndNewlines), !rawURL.isEmpty else {
            return nil
        }

        if isHTTPURL(rawURL) {
            return rawURL
        }

        if rawURL.hasPrefix("//") {
            return "https:\(rawURL)"
        }

        if rawURL.hasPrefix("/") || rawURL.contains("/") || rawURL.contains("?") {
            if let resolved = URL(string: rawURL, relativeTo: sourceURL)?.absoluteURL,
               let scheme = resolved.scheme?.lowercased(),
               ["http", "https"].contains(scheme) {
                return resolved.absoluteString
            }
        }

        let host = sourceURL.host?.lowercased() ?? ""
        if host.contains("youtube.com") || host.contains("youtu.be") {
            let id = (entry.id ?? rawURL).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { return nil }
            return "https://www.youtube.com/watch?v=\(id)"
        }

        if host.contains("bilibili.com") {
            let id = (entry.id ?? rawURL).trimmingCharacters(in: .whitespacesAndNewlines)
            if id.uppercased().hasPrefix("BV") {
                return "https://www.bilibili.com/video/\(id)"
            }
            if id.uppercased().hasPrefix("AV") {
                return "https://www.bilibili.com/video/\(id)"
            }
        }

        return nil
    }

    private func dedupeKey(for rawURL: String, policy: SourceDeduplicationPolicy) -> String? {
        switch policy {
        case .none:
            return nil
        case .normalizedURL:
            return normalizedURL(rawURL)
        }
    }

    private func normalizedURL(_ rawURL: String) -> String {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if var components = URLComponents(string: trimmed) {
            components.fragment = nil
            let value = components.string ?? trimmed
            return value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return trimmed.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func isHTTPURL(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return ["http", "https"].contains(scheme)
    }

    private func normalizedAvailability(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else {
            return "available"
        }
        switch raw {
        case "public", "available", "none":
            return "available"
        default:
            return raw
        }
    }

    private func resolvedOriginalIndex(for entry: YTDLPJSONModels.PlaylistEntry, fallback: Int) -> Int {
        if let playlistIndex = entry.playlistIndex {
            return max(0, playlistIndex - 1)
        }
        return max(0, fallback)
    }

    private func makeDiagnostics(from result: CommandExecutionResult) -> ToolExecutionDiagnostics {
        ToolExecutionDiagnostics(
            executablePath: result.executablePath,
            arguments: result.arguments,
            exitCode: result.exitCode,
            stderr: result.stderr,
            stdoutSnippet: String(result.stdout.prefix(500)),
            durationMs: result.durationMs
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
