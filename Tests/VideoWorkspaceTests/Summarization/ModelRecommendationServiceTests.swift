import XCTest
@testable import VideoWorkspace

final class ModelRecommendationServiceTests: XCTestCase {
    func testBestModelByPreferredTags() async throws {
        let discovery = StubModelDiscoveryService(models: [
            ModelDescriptor(
                id: "fast",
                displayName: "Fast",
                contextWindow: 32_000,
                capabilities: ProviderCapability(supportsTranscription: false, supportsSummarization: true, supportsStreaming: true),
                tags: [.fast]
            ),
            ModelDescriptor(
                id: "long",
                displayName: "Long",
                contextWindow: 200_000,
                capabilities: ProviderCapability(supportsTranscription: false, supportsSummarization: true, supportsStreaming: true),
                tags: [.longContext, .highQuality]
            )
        ])

        let service = ModelRecommendationService(modelDiscovery: discovery)
        let best = try await service.bestModel(for: .openAI, preferredTags: [.longContext, .highQuality])

        XCTAssertEqual(best?.modelID, "long")
    }
}

private struct StubModelDiscoveryService: ModelDiscoveryServiceProtocol {
    let models: [ModelDescriptor]

    func discoverModels(for provider: ProviderType) async throws -> [ModelDescriptor] {
        models
    }
}
