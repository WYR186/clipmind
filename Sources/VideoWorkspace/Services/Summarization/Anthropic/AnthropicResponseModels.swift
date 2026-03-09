import Foundation

struct AnthropicMessageResponse: Decodable, Sendable {
    let id: String?
    let content: [AnthropicContentBlock]
}

struct AnthropicContentBlock: Decodable, Sendable {
    let type: String
    let text: String?
}
