import Foundation

enum FFprobeJSONModels {
    struct Root: Decodable {
        let format: FormatInfo?
        let streams: [StreamInfo]
    }

    struct FormatInfo: Decodable {
        let formatName: String?
        let duration: String?
        let bitRate: String?
        let size: String?

        enum CodingKeys: String, CodingKey {
            case formatName = "format_name"
            case duration
            case bitRate = "bit_rate"
            case size
        }
    }

    struct StreamInfo: Decodable {
        let index: Int?
        let codecType: String?
        let codecName: String?
        let width: Int?
        let height: Int?
        let rFrameRate: String?
        let avgFrameRate: String?
        let sampleRate: String?
        let channels: Int?
        let bitRate: String?
        let tags: [String: String]?

        enum CodingKeys: String, CodingKey {
            case index
            case codecType = "codec_type"
            case codecName = "codec_name"
            case width
            case height
            case rFrameRate = "r_frame_rate"
            case avgFrameRate = "avg_frame_rate"
            case sampleRate = "sample_rate"
            case channels
            case bitRate = "bit_rate"
            case tags
        }
    }
}
