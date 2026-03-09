import Foundation

struct LMStudioRequestBuilder {
    private let endpoint: URL

    init(endpoint: URL = URL(string: "http://localhost:1234/v1/chat/completions")!) {
        self.endpoint = endpoint
    }

    func buildRequest(modelID: String, prompt: String, transcriptText: String, structured: Bool) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "model": modelID,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": transcriptText]
            ]
        ]

        if structured {
            payload["response_format"] = ["type": "json_object"]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}
