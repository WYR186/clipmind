import Foundation

public enum ProxyMode: String, Codable, CaseIterable, Sendable {
    case system
    case direct
    case custom
}

public enum ThemeMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}
