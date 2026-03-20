import Foundation

public struct TranslationLanguagePair: Codable, Hashable, Sendable {
    public let sourceLanguage: String
    public let targetLanguage: String

    public init(sourceLanguage: String, targetLanguage: String) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}
