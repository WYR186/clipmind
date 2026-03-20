import Foundation

enum YTDLPJSONModels {
    struct Root: Decodable {
        let id: String?
        let title: String?
        let duration: Double?
        let thumbnail: String?
        let extractor: String?
        let extractorKey: String?
        let webpageURL: String?
        let formats: [Format]
        let subtitles: [String: [SubtitleItem]]
        let automaticCaptions: [String: [SubtitleItem]]

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case duration
            case thumbnail
            case extractor
            case extractorKey = "extractor_key"
            case webpageURL = "webpage_url"
            case formats
            case subtitles
            case automaticCaptions = "automatic_captions"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            duration = try container.decodeFlexibleDoubleIfPresent(forKey: .duration)
            thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
            extractor = try container.decodeIfPresent(String.self, forKey: .extractor)
            extractorKey = try container.decodeIfPresent(String.self, forKey: .extractorKey)
            webpageURL = try container.decodeIfPresent(String.self, forKey: .webpageURL)
            formats = try container.decodeIfPresent([Format].self, forKey: .formats) ?? []
            subtitles = try container.decodeIfPresent([String: [SubtitleItem]].self, forKey: .subtitles) ?? [:]
            automaticCaptions = try container.decodeIfPresent([String: [SubtitleItem]].self, forKey: .automaticCaptions) ?? [:]
        }
    }

    struct Format: Decodable {
        let formatID: String?
        let ext: String?
        let container: String?
        let vcodec: String?
        let acodec: String?
        let width: Int?
        let height: Int?
        let fps: Double?
        let fileSize: Int64?
        let tbr: Double?
        let abr: Double?
        let asr: Int?
        let audioChannels: Int?
        let formatNote: String?
        let formatDescription: String?

        enum CodingKeys: String, CodingKey {
            case formatID = "format_id"
            case ext
            case container
            case vcodec
            case acodec
            case width
            case height
            case fps
            case fileSize = "filesize"
            case tbr
            case abr
            case asr
            case audioChannels = "audio_channels"
            case formatNote = "format_note"
            case formatDescription = "format"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formatID = try container.decodeIfPresent(String.self, forKey: .formatID)
            ext = try container.decodeIfPresent(String.self, forKey: .ext)
            self.container = try container.decodeIfPresent(String.self, forKey: .container)
            vcodec = try container.decodeIfPresent(String.self, forKey: .vcodec)
            acodec = try container.decodeIfPresent(String.self, forKey: .acodec)
            width = try container.decodeFlexibleIntIfPresent(forKey: .width)
            height = try container.decodeFlexibleIntIfPresent(forKey: .height)
            fps = try container.decodeFlexibleDoubleIfPresent(forKey: .fps)
            fileSize = try container.decodeFlexibleInt64IfPresent(forKey: .fileSize)
            tbr = try container.decodeFlexibleDoubleIfPresent(forKey: .tbr)
            abr = try container.decodeFlexibleDoubleIfPresent(forKey: .abr)
            asr = try container.decodeFlexibleIntIfPresent(forKey: .asr)
            audioChannels = try container.decodeFlexibleIntIfPresent(forKey: .audioChannels)
            formatNote = try container.decodeIfPresent(String.self, forKey: .formatNote)
            formatDescription = try container.decodeIfPresent(String.self, forKey: .formatDescription)
        }
    }

    struct SubtitleItem: Decodable {
        let ext: String?
        let url: String?
        let name: String?
    }

    struct PlaylistRoot: Decodable {
        let id: String?
        let title: String?
        let extractor: String?
        let extractorKey: String?
        let webpageURL: String?
        let thumbnail: String?
        let playlistCount: Int?
        let entries: [PlaylistEntry?]?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case extractor
            case extractorKey = "extractor_key"
            case webpageURL = "webpage_url"
            case thumbnail
            case playlistCount = "playlist_count"
            case entries
        }

        var hasPlaylistShape: Bool {
            guard let entries else { return false }
            return !entries.isEmpty
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            extractor = try container.decodeIfPresent(String.self, forKey: .extractor)
            extractorKey = try container.decodeIfPresent(String.self, forKey: .extractorKey)
            webpageURL = try container.decodeIfPresent(String.self, forKey: .webpageURL)
            thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
            playlistCount = try container.decodeFlexibleIntIfPresent(forKey: .playlistCount)
            entries = try container.decodeIfPresent([PlaylistEntry?].self, forKey: .entries)
        }
    }

    struct PlaylistEntry: Decodable {
        let id: String?
        let title: String?
        let url: String?
        let webpageURL: String?
        let duration: Double?
        let playlistIndex: Int?
        let availability: String?
        let thumbnail: String?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case url
            case webpageURL = "webpage_url"
            case duration
            case playlistIndex = "playlist_index"
            case availability
            case thumbnail
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            url = try container.decodeIfPresent(String.self, forKey: .url)
            webpageURL = try container.decodeIfPresent(String.self, forKey: .webpageURL)
            duration = try container.decodeFlexibleDoubleIfPresent(forKey: .duration)
            playlistIndex = try container.decodeFlexibleIntIfPresent(forKey: .playlistIndex)
            availability = try container.decodeIfPresent(String.self, forKey: .availability)
            thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    func decodeFlexibleInt64IfPresent(forKey key: Key) throws -> Int64? {
        if let value = try decodeIfPresent(Int64.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return Int64(value)
        }
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return Int64(value)
        }
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return Int64(value)
        }
        return nil
    }
}
