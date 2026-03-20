import XCTest
@testable import VideoWorkspace

final class KeychainSecretsStoreTests: XCTestCase {
    func testSaveUpdateLoadAndDeleteProviderSecret() async throws {
        let serviceName = "com.videoworkspace.tests.\(UUID().uuidString)"
        let service = KeychainService(serviceName: serviceName)
        let store = KeychainSecretsStore(keychainService: service)
        let key = ProviderType.openAI.rawValue

        try? await store.removeSecret(for: key)

        try await store.setSecret("sk-test-1", for: key)
        let hasInitial = try await store.hasSecret(for: key)
        let firstValue = try await store.getSecret(for: key)
        XCTAssertTrue(hasInitial)
        XCTAssertEqual(firstValue, "sk-test-1")

        try await store.updateSecret("sk-test-2", for: key)
        let updatedValue = try await store.getSecret(for: key)
        XCTAssertEqual(updatedValue, "sk-test-2")

        try await store.removeSecret(for: key)
        let hasAfterDelete = try await store.hasSecret(for: key)
        let deletedValue = try await store.getSecret(for: key)
        XCTAssertFalse(hasAfterDelete)
        XCTAssertNil(deletedValue)
    }
}
