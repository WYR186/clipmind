import Foundation

struct AnthropicMessagesRequestBuilder {
    private let endpoint: URL

    init(endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!) {
        self.endpoint = endpoint
    }

    func buildRequest(modelID: String, prompt: String, transcriptText: String, apiKey: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": modelID,
            "max_tokens": 2_048,
            "system": prompt,
            "messages": [
                [
                    "role": "user",
                    "content": transcriptText
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}
