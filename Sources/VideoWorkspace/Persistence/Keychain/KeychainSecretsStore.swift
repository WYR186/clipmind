import Foundation

actor KeychainSecretsStore: SecretsStoreProtocol {
    private let keychainService: KeychainService

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    func setSecret(_ secret: String, for key: String) async throws {
        try keychainService.setSecret(secret, account: scopedAccount(for: key))
    }

    func getSecret(for key: String) async throws -> String? {
        try keychainService.getSecret(account: scopedAccount(for: key))
    }

    func removeSecret(for key: String) async throws {
        try keychainService.removeSecret(account: scopedAccount(for: key))
    }

    func updateSecret(_ secret: String, for key: String) async throws {
        try keychainService.setSecret(secret, account: scopedAccount(for: key))
    }

    func hasSecret(for key: String) async throws -> Bool {
        try keychainService.containsSecret(account: scopedAccount(for: key))
    }

    private func scopedAccount(for key: String) -> String {
        "provider.\(key)"
    }
}
