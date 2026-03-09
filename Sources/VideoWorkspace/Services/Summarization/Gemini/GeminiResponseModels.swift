import Foundation

struct GeminiGenerateContentResponse: Decodable, Sendable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Decodable, Sendable {
    let content: GeminiContent?
}

struct GeminiContent: Decodable, Sendable {
    let parts: [GeminiPart]?
}

struct GeminiPart: Decodable, Sendable {
    let text: String?
}
