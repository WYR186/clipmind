import XCTest
@testable import VideoWorkspace

final class CompositeSummarizationServiceTests: XCTestCase {
    func testCompositeUsesChunkingAndReduce() async throws {
        let provider = StubSummaryProvider()
        let registry = StubProviderRegistry(provider: provider)
        let service = CompositeSummarizationService(
            providerRegistry: registry,
            fallbackService: nil,
            allowFallbackToMock: false,
            logger: ConsoleLogger()
        )

        let transcript = TranscriptItem(
            taskID: UUID(),
            sourceType: .asr,
            languageCode: "en",
            format: .txt,
            content: String(repeating: "Long transcript ", count: 1200)
        )

        let request = SummarizationRequest(
            taskID: UUID(),
            transcript: transcript,
            summaryRequest: SummaryRequest(
                provider: .openAI,
                modelID: "m1",
                mode: .abstractSummary,
                length: .medium,
                outputLanguage: "en",
                prompt: "",
                templateKind: .general,
                chunkingStrategy: .sizeBased,
                outputFormat: .markdown
            )
        )

        let result = try await service.summarize(request: request, progressHandler: nil)

        XCTAssertFalse(result.content.isEmpty)
        let callCount = await provider.calls()
        XCTAssertGreaterThan(callCount, 1)
    }

    func testCompositeFallbackWhenProviderUnavailable() async throws {
        let registry = EmptyProviderRegistry()
        let fallback = StubFallbackSummarizationService()

        let service = CompositeSummarizationService(
            providerRegistry: registry,
            fallbackService: fallback,
            allowFallbackToMock: true,
            logger: ConsoleLogger()
        )

        let transcript = TranscriptItem(taskID: UUID(), sourceType: .asr, languageCode: "en", format: .txt, content: "abc")
        let request = SummarizationRequest(
            taskID: UUID(),
            transcript: transcript,
            summaryRequest: SummaryRequest(
                provider: .openAI,
                modelID: "m1",
                mode: .abstractSummary,
                length: .short,
                outputLanguage: "en",
                prompt: ""
            )
        )

        let result = try await service.summarize(request: request, progressHandler: nil)
        XCTAssertEqual(result.content, "fallback")
    }
}

private final class StubSummaryProvider: @unchecked Sendable, LLMProviderProtocol {
    let type: ProviderType = .openAI
    private let counter = CallCounter()

    func models() async throws -> [ModelDescriptor] { [] }

    func connectionStatus() async -> ProviderConnectionStatus {
        .connected
    }

    func summarize(taskID: UUID, transcript: TranscriptItem, request: SummaryRequest) async throws -> SummaryResult {
        let current = await counter.increment()

        let payload = "{\"title\":\"S\",\"keyPoints\":[\"P\"],\"sections\":[]}"
        let content = request.prompt.contains("aggregating chunk summaries") ? payload : "Chunk \(current) summary"
        return SummaryResult(
            taskID: taskID,
            provider: .openAI,
            modelID: request.modelID,
            mode: request.mode,
            length: request.length,
            content: content
        )
    }

    func calls() async -> Int {
        await counter.value()
    }
}

private actor CallCounter {
    private var count: Int = 0

    func increment() -> Int {
        count += 1
        return count
    }

    func value() -> Int {
        count
    }
}

private actor StubProviderRegistry: ProviderRegistryProtocol {
    let providerInstance: StubSummaryProvider

    init(provider: StubSummaryProvider) {
        self.providerInstance = provider
    }

    func availableProviders() async -> [ProviderType] { [.openAI] }

    func connectionStatus(for provider: ProviderType) async -> ProviderConnectionStatus {
        .connected
    }

    func provider(for providerType: ProviderType) async -> (any LLMProviderProtocol)? {
        providerType == .openAI ? providerInstance : nil
    }
}

private actor EmptyProviderRegistry: ProviderRegistryProtocol {
    func availableProviders() async -> [ProviderType] { [] }
    func connectionStatus(for provider: ProviderType) async -> ProviderConnectionStatus { .disconnected }
    func provider(for providerType: ProviderType) async -> (any LLMProviderProtocol)? { nil }
}

private struct StubFallbackSummarizationService: SummarizationServiceProtocol {
    func summarize(
        request: SummarizationRequest,
        progressHandler: (@Sendable (TaskProgress) -> Void)?
    ) async throws -> SummaryResult {
        SummaryResult(
            taskID: request.taskID,
            provider: request.summaryRequest.provider,
            modelID: request.summaryRequest.modelID,
            mode: request.summaryRequest.mode,
            length: request.summaryRequest.length,
            content: "fallback"
        )
    }
}
