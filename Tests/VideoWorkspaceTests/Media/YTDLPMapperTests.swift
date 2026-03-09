import XCTest
@testable import VideoWorkspace

final class YTDLPMapperTests: XCTestCase {
    func testMapperProducesNormalizedMetadata() throws {
        let json = """
        {
          "id": "abc",
          "title": "Sample Video",
          "duration": 123,
          "thumbnail": "https://img.example.com/a.jpg",
          "extractor": "youtube",
          "extractor_key": "Youtube",
          "webpage_url": "https://youtube.com/watch?v=abc",
          "formats": [
            {
              "format_id": "137",
              "ext": "mp4",
              "container": "mp4_dash",
              "vcodec": "avc1.640028",
              "acodec": "none",
              "width": 1920,
              "height": 1080,
              "fps": 30,
              "filesize": 100000000,
              "tbr": 2500,
              "format_note": "1080p",
              "format": "1080p video"
            },
            {
              "format_id": "251",
              "ext": "webm",
              "container": "webm_dash",
              "vcodec": "none",
              "acodec": "opus",
              "filesize": 12000000,
              "tbr": 160,
              "abr": 160,
              "asr": 48000,
              "audio_channels": 2,
              "format_note": "audio only",
              "format": "audio"
            }
          ],
          "subtitles": {
            "en": [
              { "ext": "vtt", "url": "https://a" }
            ]
          },
          "automatic_captions": {
            "zh": [
              { "ext": "vtt", "url": "https://b" }
            ]
          }
        }
        """

        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(YTDLPJSONModels.Root.self, from: data)
        let source = MediaSource(type: .url, value: "https://youtube.com/watch?v=abc")

        let mapped = try YTDLPMapper().map(source: source, payload: payload)

        XCTAssertEqual(mapped.title, "Sample Video")
        XCTAssertEqual(mapped.platform, "youtube")
        XCTAssertEqual(mapped.videoOptions.count, 1)
        XCTAssertEqual(mapped.audioOptions.count, 1)
        XCTAssertEqual(mapped.subtitleTracks.count, 2)
    }
}
