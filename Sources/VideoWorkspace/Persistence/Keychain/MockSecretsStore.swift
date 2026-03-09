import Foundation

actor MockSecretsStore: SecretsStoreProtocol {
    private var storage: [String: String] = [:]

    func setSecret(_ secret: String, for key: String) async throws {
        storage[key] = secret
    }

    func getSecret(for key: String) async throws -> String? {
        storage[key]
    }

    func removeSecret(for key: String) async throws {
        storage[key] = nil
    }
}
