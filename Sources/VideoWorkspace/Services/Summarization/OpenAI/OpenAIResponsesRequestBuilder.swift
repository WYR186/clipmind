import Foundation

struct OpenAIResponsesRequestBuilder {
    private let endpoint: URL

    init(endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!) {
        self.endpoint = endpoint
    }

    func buildRequest(modelID: String, prompt: String, transcriptText: String, apiKey: String, structured: Bool) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "model": modelID,
            "input": [
                [
                    "role": "system",
                    "content": [["type": "input_text", "text": prompt]]
                ],
                [
                    "role": "user",
                    "content": [["type": "input_text", "text": transcriptText]]
                ]
            ]
        ]

        if structured {
            payload["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": "summary_payload",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string"],
                            "abstractSummary": ["type": "string"],
                            "keyPoints": ["type": "array", "items": ["type": "string"]],
                            "sections": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "title": ["type": "string"],
                                        "content": ["type": "string"]
                                    ],
                                    "required": ["title", "content"]
                                ]
                            ]
                        ],
                        "required": ["keyPoints"]
                    ]
                ]
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}
