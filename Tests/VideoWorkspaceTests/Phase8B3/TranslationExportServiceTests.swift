import XCTest
@testable import VideoWorkspace

final class TranslationExportServiceTests: XCTestCase {
    func testExportBilingualMarkdownAndSubtitleFormats() throws {
        let service = TranslationExportService()
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vw-translation-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let request = TranslationRequest(
            taskID: UUID(),
            sourceText: "hello",
            sourceSegments: [TranscriptSegment(index: 0, startSeconds: 0, endSeconds: 1, text: "hello")],
            sourceFormat: .srt,
            languagePair: TranslationLanguagePair(sourceLanguage: "en", targetLanguage: "zh"),
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .subtitlePreserving,
            bilingualOutputEnabled: true,
            preserveTimestamps: true,
            preserveTerminology: true,
            outputFormats: [.markdown, .srt, .vtt],
            outputDirectory: tempDirectory.path,
            overwritePolicy: .replace
        )

        let artifacts = try service.write(
            request: request,
            translatedText: "你好",
            bilingualText: "- hello\n  你好",
            translatedSegments: [
                TranslationSegment(index: 0, startSeconds: 0, endSeconds: 1, sourceText: "hello", translatedText: "你好")
            ]
        )

        XCTAssertEqual(artifacts.count, 3)
        XCTAssertTrue(artifacts.contains(where: { $0.format == .markdown }))
        XCTAssertTrue(artifacts.contains(where: { $0.format == .srt }))
        XCTAssertTrue(artifacts.contains(where: { $0.format == .vtt }))

        for artifact in artifacts {
            XCTAssertTrue(FileManager.default.fileExists(atPath: artifact.path))
        }
    }
}
