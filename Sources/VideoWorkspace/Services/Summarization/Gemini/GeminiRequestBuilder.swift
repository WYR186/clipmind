import Foundation

struct GeminiRequestBuilder {
    func buildRequest(modelID: String, prompt: String, transcriptText: String, apiKey: String, structured: Bool) throws -> URLRequest {
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt + "\n\nTranscript:\n" + transcriptText]
                    ]
                ]
            ]
        ]

        if structured {
            payload["generationConfig"] = [
                "responseMimeType": "application/json"
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}
