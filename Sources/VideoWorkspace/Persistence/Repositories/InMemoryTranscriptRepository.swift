import Foundation

actor InMemoryTranscriptRepository: TranscriptRepositoryProtocol {
    private var storage: [UUID: TranscriptItem] = [:]

    func upsertTranscript(_ transcript: TranscriptItem, historyID: UUID?) async {
        storage[transcript.id] = transcript
    }

    func transcript(id: UUID) async -> TranscriptItem? {
        storage[id]
    }
}
