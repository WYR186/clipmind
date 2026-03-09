import XCTest
@testable import VideoWorkspace

final class DownloadCommandBuilderTests: XCTestCase {
    func testBuildVideoDownloadArguments() throws {
        let builder = YTDLPDownloadCommandBuilder()
        let request = MediaDownloadRequest(
            source: MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"),
            kind: .video,
            selectedVideoFormatID: "137",
            selectedAudioFormatID: "140"
        )

        let args = try builder.buildArguments(request: request, outputTemplatePath: "/tmp/a.%(ext)s")

        XCTAssertTrue(args.contains("-f"))
        XCTAssertTrue(args.contains("137+140/137"))
        XCTAssertEqual(args.last, "https://youtube.com/watch?v=abc")
    }

    func testBuildSubtitleArguments() throws {
        let builder = YTDLPDownloadCommandBuilder()
        let request = MediaDownloadRequest(
            source: MediaSource(type: .url, value: "https://youtube.com/watch?v=abc"),
            kind: .subtitle,
            selectedSubtitleTrack: SubtitleTrack(languageCode: "en", languageName: "English", sourceType: .native),
            preferredSubtitleFormat: .srt
        )

        let args = try builder.buildArguments(request: request, outputTemplatePath: "/tmp/s.%(ext)s")

        XCTAssertTrue(args.contains("--write-subs"))
        XCTAssertTrue(args.contains("--sub-langs"))
        XCTAssertTrue(args.contains("en"))
        XCTAssertTrue(args.contains("--convert-subs"))
        XCTAssertTrue(args.contains("srt"))
    }
}
