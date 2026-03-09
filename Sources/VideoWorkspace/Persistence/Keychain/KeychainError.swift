import Foundation

public enum KeychainError: Error, Sendable {
    case keychainReadFailed(status: OSStatus)
    case keychainWriteFailed(status: OSStatus)
    case keychainDeleteFailed(status: OSStatus)
    case keychainUnexpectedData
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .keychainReadFailed:
            return "Failed to read secret from Keychain."
        case .keychainWriteFailed:
            return "Failed to save secret to Keychain."
        case .keychainDeleteFailed:
            return "Failed to delete secret from Keychain."
        case .keychainUnexpectedData:
            return "Keychain returned invalid secret data."
        }
    }
}
