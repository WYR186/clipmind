import XCTest
@testable import VideoWorkspace

final class FFprobeMapperTests: XCTestCase {
    func testMapperProducesStreamMetadata() throws {
        let source = MediaSource(type: .localFile, value: "/tmp/demo.mp4")
        let payload = FFprobeJSONModels.Root(
            format: FFprobeJSONModels.FormatInfo(formatName: "mov,mp4,m4a,3gp,3g2,mj2", duration: "120.5", bitRate: "2000000", size: "9000000"),
            streams: [
                FFprobeJSONModels.StreamInfo(index: 0, codecType: "video", codecName: "h264", width: 1920, height: 1080, rFrameRate: "30/1", avgFrameRate: "30/1", sampleRate: nil, channels: nil, bitRate: "1800000", tags: nil),
                FFprobeJSONModels.StreamInfo(index: 1, codecType: "audio", codecName: "aac", width: nil, height: nil, rFrameRate: nil, avgFrameRate: nil, sampleRate: "48000", channels: 2, bitRate: "192000", tags: nil),
                FFprobeJSONModels.StreamInfo(index: 2, codecType: "subtitle", codecName: "mov_text", width: nil, height: nil, rFrameRate: nil, avgFrameRate: nil, sampleRate: nil, channels: nil, bitRate: nil, tags: ["language": "en"])
            ]
        )

        let mapped = try FFprobeMapper().map(source: source, payload: payload)

        XCTAssertEqual(mapped.container, "mov,mp4,m4a,3gp,3g2,mj2")
        XCTAssertEqual(mapped.videoOptions.count, 1)
        XCTAssertEqual(mapped.audioOptions.count, 1)
        XCTAssertEqual(mapped.subtitleTracks.count, 1)
    }
}
