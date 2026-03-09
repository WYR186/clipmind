import Foundation

struct OpenAITranscriptionBuiltRequest: Sendable {
    let urlRequest: URLRequest
    let body: Data
}

struct OpenAITranscriptionRequestBuilder {
    private let endpoint: URL

    init(endpoint: URL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!) {
        self.endpoint = endpoint
    }

    func build(
        request: TranscriptionRequest,
        fileURL: URL,
        apiKey: String
    ) throws -> OpenAITranscriptionBuiltRequest {
        let boundary = "Boundary-\(UUID().uuidString)"

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileName = fileURL.lastPathComponent
        let mimeType = mimeTypeFor(fileURL: fileURL)
        let fileData = try Data(contentsOf: fileURL)

        var body = Data()
        appendField(name: "model", value: request.modelIdentifier, boundary: boundary, to: &body)

        if let language = request.languageHint?.trimmingCharacters(in: .whitespacesAndNewlines), !language.isEmpty {
            appendField(name: "language", value: language, boundary: boundary, to: &body)
        }

        if let prompt = request.promptHint?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty {
            appendField(name: "prompt", value: prompt, boundary: boundary, to: &body)
        }

        if let temperature = request.temperature {
            appendField(name: "temperature", value: String(temperature), boundary: boundary, to: &body)
        }

        appendField(name: "response_format", value: "verbose_json", boundary: boundary, to: &body)
        if request.useOpenAITimestampGranularity {
            appendField(name: "timestamp_granularities[]", value: "segment", boundary: boundary, to: &body)
        }

        appendFile(
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: fileData,
            boundary: boundary,
            to: &body
        )

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return OpenAITranscriptionBuiltRequest(urlRequest: urlRequest, body: body)
    }

    private func appendField(name: String, value: String, boundary: String, to body: inout Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func appendFile(
        fieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        boundary: String,
        to body: inout Data
    ) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
    }

    private func mimeTypeFor(fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "mp4":
            return "video/mp4"
        case "webm":
            return "video/webm"
        default:
            return "application/octet-stream"
        }
    }
}
