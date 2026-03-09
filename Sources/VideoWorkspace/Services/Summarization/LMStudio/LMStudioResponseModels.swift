import Foundation

struct LMStudioChatResponse: Decodable, Sendable {
    let choices: [LMStudioChoice]
}

struct LMStudioChoice: Decodable, Sendable {
    let message: LMStudioMessage
}

struct LMStudioMessage: Decodable, Sendable {
    let content: String?
}

struct LMStudioModelListResponse: Decodable {
    let data: [LMStudioModelItem]
}

struct LMStudioModelItem: Decodable {
    let id: String
}
