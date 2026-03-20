import XCTest
@testable import VideoWorkspace

final class ArtifactIndexingServiceTests: XCTestCase {
    func testIndexingRegistersDownloadTranscriptAndSummaryArtifacts() async {
        let repository = InMemoryArtifactRepository()
        let service = ArtifactIndexingService(
            artifactRepository: repository,
            logger: ConsoleLogger()
        )

        let taskID = UUID()
        let historyID = UUID()

        let transcript = TranscriptItem(
            taskID: taskID,
            sourceType: .asr,
            languageCode: "en",
            format: .txt,
            content: "demo",
            artifacts: [TranscriptArtifact(kind: .txt, path: "/tmp/t.txt")],
            backend: .whisperCPP,
            modelID: "base"
        )

        let summary = SummaryResult(
            taskID: taskID,
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .keyPoints,
            length: .short,
            content: "summary",
            artifacts: [SummaryArtifact(format: .markdown, path: "/tmp/s.md")]
        )

        let entry = HistoryEntry(
            id: historyID,
            taskID: taskID,
            source: MediaSource(type: .url, value: "https://example.com/video"),
            taskType: .summarize,
            transcript: transcript,
            summary: summary,
            downloadResult: MediaDownloadResult(kind: .audioOnly, outputPath: "/tmp/a.m4a", outputFileName: "a.m4a")
        )

        await service.indexArtifacts(for: entry)

        let indexed = await repository.artifacts(forHistoryID: historyID)
        XCTAssertEqual(indexed.count, 3)
        XCTAssertTrue(indexed.contains { $0.artifactType == .downloadAudio })
        XCTAssertTrue(indexed.contains { $0.artifactType == .transcriptTXT })
        XCTAssertTrue(indexed.contains { $0.artifactType == .summaryMarkdown })
    }
}
