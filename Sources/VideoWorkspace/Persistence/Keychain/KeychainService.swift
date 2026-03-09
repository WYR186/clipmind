import Foundation
import Security

struct KeychainService {
    let serviceName: String

    init(serviceName: String = "com.videoworkspace.provider-secrets") {
        self.serviceName = serviceName
    }

    func setSecret(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            return
        }

        guard status == errSecDuplicateItem else {
            throw KeychainError.keychainWriteFailed(status: status)
        }

        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw KeychainError.keychainWriteFailed(status: updateStatus)
        }
    }

    func getSecret(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.keychainReadFailed(status: status)
        }

        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.keychainUnexpectedData
        }

        return value
    }

    func removeSecret(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainError.keychainDeleteFailed(status: status)
    }

    func containsSecret(account: String) throws -> Bool {
        try getSecret(account: account) != nil
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
    }
}
