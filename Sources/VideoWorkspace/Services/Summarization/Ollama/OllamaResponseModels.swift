import Foundation

struct OllamaChatResponse: Decodable, Sendable {
    let message: OllamaMessage?
}

struct OllamaMessage: Decodable, Sendable {
    let role: String?
    let content: String?
}

struct OllamaTagsResponse: Decodable {
    let models: [OllamaTagModel]
}

struct OllamaTagModel: Decodable {
    let name: String
}
