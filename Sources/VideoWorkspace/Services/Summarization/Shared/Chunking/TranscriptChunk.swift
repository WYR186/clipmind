import Foundation

struct TranscriptChunk: Identifiable, Sendable {
    let id: UUID
    let index: Int
    let text: String
    let startSeconds: Double?
    let endSeconds: Double?

    init(
        id: UUID = UUID(),
        index: Int,
        text: String,
        startSeconds: Double? = nil,
        endSeconds: Double? = nil
    ) {
        self.id = id
        self.index = index
        self.text = text
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }
}
