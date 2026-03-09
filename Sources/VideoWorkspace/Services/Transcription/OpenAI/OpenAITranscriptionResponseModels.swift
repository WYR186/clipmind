import Foundation

struct OpenAITranscriptionResponse: Decodable, Sendable {
    let text: String
    let language: String?
    let duration: Double?
    let segments: [OpenAITranscriptionSegment]?
}

struct OpenAITranscriptionSegment: Decodable, Sendable {
    let id: Int?
    let start: Double
    let end: Double
    let text: String
}
