import XCTest
@testable import VideoWorkspace

final class MockProviderRegistryTests: XCTestCase {
    func testRegistryReturnsProvidersAndModels() async throws {
        let registry = MockProviderRegistry()
        let providers = await registry.availableProviders()

        XCTAssertFalse(providers.isEmpty)
        XCTAssertTrue(providers.contains(.openAI))

        let models = try await registry.discoverModels(for: .openAI)
        XCTAssertFalse(models.isEmpty)
    }
}
