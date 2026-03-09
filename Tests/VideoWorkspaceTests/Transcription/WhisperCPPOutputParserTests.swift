import XCTest
@testable import VideoWorkspace

final class WhisperCPPOutputParserTests: XCTestCase {
    func testParseTxtAndSRT() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("whisper-output-\(UUID().uuidString)")
        let txtURL = base.appendingPathExtension("txt")
        let srtURL = base.appendingPathExtension("srt")

        try "hello world".write(to: txtURL, atomically: true, encoding: .utf8)
        try """
        1
        00:00:00,000 --> 00:00:01,200
        hello

        2
        00:00:01,200 --> 00:00:02,400
        world
        """.write(to: srtURL, atomically: true, encoding: .utf8)

        let parser = WhisperCPPOutputParser()
        let parsed = try parser.parse(outputBasePath: base.path)

        XCTAssertEqual(parsed.text, "hello world")
        XCTAssertEqual(parsed.segments.count, 2)
        XCTAssertEqual(parsed.segments[0].text, "hello")
        XCTAssertEqual(parsed.segments[1].endSeconds, 2.4, accuracy: 0.001)
    }
}
