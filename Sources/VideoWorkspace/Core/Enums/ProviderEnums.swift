import Foundation

public enum ProviderType: String, Codable, CaseIterable, Sendable {
    case openAI
    case anthropic
    case gemini
    case ollama
    case lmStudio
}

public enum ProviderConnectionStatus: String, Codable, Sendable {
    case unknown
    case connected
    case disconnected
    case unauthorized
}
