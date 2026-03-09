import Foundation

public protocol SummarizationServiceProtocol: Sendable {
    func summarize(
        request: SummarizationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> SummaryResult
}

public extension SummarizationServiceProtocol {
    func summarize(request: SummarizationRequest) async throws -> SummaryResult {
        try await summarize(request: request, progressHandler: nil)
    }

    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult {
        try await summarize(
            request: SummarizationRequest(taskID: taskID, transcript: transcript, summaryRequest: request),
            progressHandler: nil
        )
    }
}

public protocol LLMProviderProtocol: Sendable {
    var type: ProviderType { get }
    func models() async throws -> [ModelDescriptor]
    func connectionStatus() async -> ProviderConnectionStatus
    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult
}

public extension LLMProviderProtocol {
    func connectionStatus() async -> ProviderConnectionStatus {
        .unknown
    }
}
