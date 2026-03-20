import Foundation

public enum TranslationMode: String, Codable, CaseIterable, Sendable {
    case plain
    case subtitlePreserving
    case bilingual
}
