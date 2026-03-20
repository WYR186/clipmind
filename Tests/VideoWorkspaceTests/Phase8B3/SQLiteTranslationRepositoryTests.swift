import XCTest
@testable import VideoWorkspace

final class SQLiteTranslationRepositoryTests: XCTestCase {
    func testPersistAndLoadTranslationResult() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "sqlite-translation")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let logger = ConsoleLogger()
        let manager = try DatabaseManager(configuration: configuration, logger: logger)
        let repository = SQLiteTranslationRepository(databaseManager: manager, logger: logger)

        let taskID = UUID()
        let transcriptID = UUID()
        let translation = TranslationResult(
            taskID: taskID,
            sourceTranscriptID: transcriptID,
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            languagePair: TranslationLanguagePair(sourceLanguage: "en", targetLanguage: "zh"),
            mode: .subtitlePreserving,
            style: .faithful,
            translatedText: "你好\n世界",
            bilingualText: "- hello\n  你好",
            segments: [
                TranslationSegment(index: 0, startSeconds: 0, endSeconds: 1, sourceText: "hello", translatedText: "你好")
            ],
            artifacts: [
                TranslationArtifact(format: .srt, path: "/tmp/demo.srt")
            ],
            diagnostics: "segments=1"
        )

        await repository.upsertTranslation(translation, historyID: UUID())
        let loaded = await repository.translation(id: translation.id)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.taskID, taskID)
        XCTAssertEqual(loaded?.sourceTranscriptID, transcriptID)
        XCTAssertEqual(loaded?.provider, .openAI)
        XCTAssertEqual(loaded?.languagePair.targetLanguage, "zh")
        XCTAssertEqual(loaded?.segments.count, 1)
        XCTAssertEqual(loaded?.artifacts.first?.format, .srt)
    }
}
