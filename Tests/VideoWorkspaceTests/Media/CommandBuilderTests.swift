import XCTest
@testable import VideoWorkspace

final class CommandBuilderTests: XCTestCase {
    func testYTDLPCommandBuilder() {
        let builder = YTDLPCommandBuilder()
        let args = builder.buildInspectArguments(url: "https://youtube.com/watch?v=abc")

        XCTAssertEqual(args.first, "--dump-single-json")
        XCTAssertEqual(args.last, "https://youtube.com/watch?v=abc")
        XCTAssertTrue(args.contains("--skip-download"))
    }

    func testYTDLPPlaylistCommandBuilder() {
        let builder = YTDLPCommandBuilder()
        let args = builder.buildPlaylistInspectArguments(url: "https://youtube.com/playlist?list=PL123")

        XCTAssertEqual(args.first, "--dump-single-json")
        XCTAssertEqual(args.last, "https://youtube.com/playlist?list=PL123")
        XCTAssertTrue(args.contains("--yes-playlist"))
        XCTAssertTrue(args.contains("--ignore-errors"))
    }

    func testFFprobeCommandBuilder() {
        let builder = FFprobeCommandBuilder()
        let args = builder.buildInspectArguments(filePath: "/tmp/a.mp4")

        XCTAssertEqual(args.suffix(2), ["--", "/tmp/a.mp4"])
        XCTAssertTrue(args.contains("-show_streams"))
        XCTAssertTrue(args.contains("-print_format"))
    }
}
