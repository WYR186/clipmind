import XCTest
@testable import VideoWorkspace

final class SQLiteHistoryRepositoryTests: XCTestCase {
    func testPersistAndLoadHistoryWithTranscriptAndSummary() async throws {
        let configuration = SQLiteTestSupport.makeTemporaryConfiguration(fileName: "sqlite-history")
        defer { SQLiteTestSupport.cleanupDatabase(for: configuration) }

        let logger = ConsoleLogger()
        let manager = try DatabaseManager(configuration: configuration, logger: logger)

        let transcriptRepository = SQLiteTranscriptRepository(databaseManager: manager, logger: logger)
        let summaryRepository = SQLiteSummaryRepository(databaseManager: manager, logger: logger)
        let translationRepository = SQLiteTranslationRepository(databaseManager: manager, logger: logger)
        let historyRepository = SQLiteHistoryRepository(
            databaseManager: manager,
            transcriptRepository: transcriptRepository,
            summaryRepository: summaryRepository,
            translationRepository: translationRepository,
            logger: logger
        )

        let taskID = UUID()
        let source = MediaSource(type: .localFile, value: "/tmp/session.mov")

        let transcript = TranscriptItem(
            taskID: taskID,
            sourceType: .asr,
            languageCode: "en",
            format: .txt,
            content: "hello world",
            segments: [TranscriptSegment(index: 0, startSeconds: 0, endSeconds: 1, text: "hello")],
            artifacts: [TranscriptArtifact(kind: .txt, path: "/tmp/session.txt")],
            backend: .openAI,
            modelID: "gpt-4o-mini-transcribe",
            detectedLanguage: "en"
        )

        let summary = SummaryResult(
            taskID: taskID,
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .abstractSummary,
            length: .short,
            content: "summary",
            artifacts: [SummaryArtifact(format: .markdown, path: "/tmp/session-summary.md")],
            templateKind: .general,
            outputLanguage: "zh"
        )

        let downloadResult = MediaDownloadResult(
            kind: .audioOnly,
            outputPath: "/tmp/session.m4a",
            outputFileName: "session.m4a"
        )
        let translation = TranslationResult(
            taskID: taskID,
            sourceTranscriptID: transcript.id,
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            languagePair: TranslationLanguagePair(sourceLanguage: "en", targetLanguage: "zh"),
            mode: .plain,
            style: .faithful,
            translatedText: "你好，世界",
            artifacts: [TranslationArtifact(format: .txt, path: "/tmp/session-zh.txt")]
        )

        let entry = HistoryEntry(
            taskID: taskID,
            source: source,
            taskType: .summarize,
            transcript: transcript,
            summary: summary,
            translation: translation,
            downloadResult: downloadResult
        )

        await historyRepository.addHistoryEntry(entry)
        let entries = await historyRepository.allHistoryEntries()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.taskID, taskID)
        XCTAssertEqual(entries.first?.transcript?.content, "hello world")
        XCTAssertEqual(entries.first?.summary?.content, "summary")
        XCTAssertEqual(entries.first?.translation?.translatedText, "你好，世界")
        XCTAssertEqual(entries.first?.downloadResult?.outputPath, "/tmp/session.m4a")
    }
}
