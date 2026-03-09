import Foundation

struct OllamaRequestBuilder {
    private let endpoint: URL

    init(endpoint: URL = URL(string: "http://localhost:11434/api/chat")!) {
        self.endpoint = endpoint
    }

    func buildRequest(modelID: String, prompt: String, transcriptText: String, structured: Bool) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "model": modelID,
            "stream": false,
            "messages": [
                [
                    "role": "user",
                    "content": prompt + "\n\nTranscript:\n" + transcriptText
                ]
            ]
        ]

        if structured {
            payload["format"] = "json"
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}
