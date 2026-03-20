import Foundation

struct ExpandedSourceMapper: ExpandedSourceMappingServiceProtocol {
    func mapToBatchCreationRequest(
        expansionResult: SourceExpansionResult,
        operationTemplate: BatchOperationTemplate,
        preferredTitle: String?
    ) throws -> BatchCreationRequest {
        let selectedValidItems = expansionResult.expandedItems
            .filter { $0.isValid && $0.isSelected }

        guard !selectedValidItems.isEmpty else {
            throw ExpandedSourceMapperError.noSelectedItems
        }

        var seen: Set<String> = []
        var sources: [MediaSource] = []

        for item in selectedValidItems {
            guard let sourceURL = item.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !sourceURL.isEmpty else {
                continue
            }
            let dedupeKey = sourceURL.lowercased()
            guard seen.insert(dedupeKey).inserted else {
                continue
            }
            sources.append(MediaSource(type: .url, value: sourceURL))
        }

        guard !sources.isEmpty else {
            throw ExpandedSourceMapperError.noSelectedItems
        }

        let resolvedTitle: String? = {
            if let preferredTitle = preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !preferredTitle.isEmpty {
                return preferredTitle
            }
            if let metadata = expansionResult.playlistMetadata {
                return "\(operationTemplate.operationType.rawValue.capitalized) Playlist Batch (\(metadata.title))"
            }
            return nil
        }()

        let sourceDescriptor: String? = {
            guard let metadata = expansionResult.playlistMetadata else {
                return nil
            }
            return "playlist:\(metadata.title)"
        }()

        let sourceMetadataJSON: String? = {
            guard let metadata = expansionResult.playlistMetadata,
                  let data = try? JSONEncoder().encode(metadata) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }()

        return BatchCreationRequest(
            title: resolvedTitle,
            sourceType: .urlBatch,
            sources: sources,
            operationTemplate: operationTemplate,
            sourceDescriptor: sourceDescriptor,
            sourceMetadataJSON: sourceMetadataJSON
        )
    }
}
