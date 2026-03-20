import Foundation

public protocol SourceExpansionServiceProtocol: Sendable {
    func isLikelyPlaylistURL(_ rawURL: String) -> Bool
    func expand(request: SourceExpansionRequest) async throws -> SourceExpansionResult
}

public protocol PlaylistExpansionServiceProtocol: Sendable {
    func expandPlaylist(
        url: String,
        deduplicationPolicy: SourceDeduplicationPolicy,
        selectionDefault: ExpandedSourceSelectionDefault
    ) async throws -> SourceExpansionResult
}

public protocol ExpandedSourceMappingServiceProtocol: Sendable {
    func mapToBatchCreationRequest(
        expansionResult: SourceExpansionResult,
        operationTemplate: BatchOperationTemplate,
        preferredTitle: String?
    ) throws -> BatchCreationRequest
}
