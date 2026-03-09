import Foundation

struct OpenAIResponsesResponse: Decodable, Sendable {
    let id: String?
    let outputText: String?
    let output: [OpenAIResponseOutputItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case outputText = "output_text"
        case output
    }
}

struct OpenAIResponseOutputItem: Decodable, Sendable {
    let content: [OpenAIResponseContentItem]?
}

struct OpenAIResponseContentItem: Decodable, Sendable {
    let type: String?
    let text: String?
}
