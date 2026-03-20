import XCTest
@testable import VideoWorkspace

final class SubtitleTranslationMapperTests: XCTestCase {
    func testSourceSegmentsFallbackFromTextLines() {
        let mapper = SubtitleTranslationMapper()
        let request = TranslationRequest(
            taskID: UUID(),
            sourceText: "Line one\nLine two",
            languagePair: TranslationLanguagePair(sourceLanguage: "en", targetLanguage: "zh"),
            provider: .openAI,
            modelID: "gpt-4.1-mini",
            mode: .plain,
            bilingualOutputEnabled: false,
            preserveTimestamps: false,
            preserveTerminology: true,
            outputFormats: [.txt]
        )

        let segments = mapper.sourceSegments(for: request)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].text, "Line one")
        XCTAssertEqual(segments[1].text, "Line two")
    }

    func testBilingualOutputFromSegments() {
        let mapper = SubtitleTranslationMapper()
        let segments = [
            TranslationSegment(index: 0, sourceText: "hello", translatedText: "你好"),
            TranslationSegment(index: 1, sourceText: "world", translatedText: "世界")
        ]

        let bilingual = mapper.makeBilingualText(from: segments)
        XCTAssertTrue(bilingual.contains("hello"))
        XCTAssertTrue(bilingual.contains("你好"))
        XCTAssertTrue(bilingual.contains("world"))
        XCTAssertTrue(bilingual.contains("世界"))
    }

    func testSubtitleSegmentsPreserveTiming() {
        let mapper = SubtitleTranslationMapper()
        let segments = [
            TranslationSegment(index: 0, startSeconds: 1.2, endSeconds: 2.5, sourceText: "A", translatedText: "甲"),
            TranslationSegment(index: 1, startSeconds: 3.0, endSeconds: 4.5, sourceText: "B", translatedText: "乙")
        ]

        let subtitleSegments = mapper.subtitleSegments(from: segments)
        XCTAssertEqual(subtitleSegments.count, 2)
        XCTAssertEqual(subtitleSegments[0].startSeconds, 1.2, accuracy: 0.001)
        XCTAssertEqual(subtitleSegments[0].endSeconds, 2.5, accuracy: 0.001)
        XCTAssertEqual(subtitleSegments[1].startSeconds, 3.0, accuracy: 0.001)
        XCTAssertEqual(subtitleSegments[1].endSeconds, 4.5, accuracy: 0.001)
    }
}
