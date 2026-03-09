import Foundation

struct MockSummarizationService: SummarizationServiceProtocol {
    let providerRegistry: any ProviderRegistryProtocol

    func summarize(
        request: SummarizationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> SummaryResult {
        guard let provider = await providerRegistry.provider(for: request.summaryRequest.provider) else {
            throw AppServiceError.providerUnavailable
        }

        progressHandler?(TaskProgressFactory.step(0.3, description: "Mock summary in progress"))
        try await Task.sleep(nanoseconds: 700_000_000)
        progressHandler?(TaskProgressFactory.step(1.0, description: "Mock summary completed"))
        return try await provider.summarize(
            taskID: request.taskID,
            transcript: request.transcript,
            request: request.summaryRequest
        )
    }
}
