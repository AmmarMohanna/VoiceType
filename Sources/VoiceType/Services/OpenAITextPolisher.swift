import Foundation

enum OpenAITextPolisher {
    static func polish(_ transcript: String, apiKey: String) async throws -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return trimmed
        }

        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-5.4-mini",
            "input": [
                [
                    "role": "system",
                    "content": [
                        [
                            "type": "input_text",
                            "text": """
                            Clean this dictated text for direct clipboard use. Fix punctuation, casing, spacing, and obvious speech-to-text artifacts. Preserve the user's meaning and wording. Return only the cleaned text.
                            """
                        ]
                    ]
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": trimmed
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw NSError(
                domain: "OpenAITextPolisher",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        let object = try JSONSerialization.jsonObject(with: data)
        if let dictionary = object as? [String: Any] {
            if let outputText = dictionary["output_text"] as? String {
                return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let extracted = extractText(from: dictionary) {
                return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return trimmed
    }

    private static func extractText(from value: Any) -> String? {
        if let string = value as? String {
            return string
        }

        if let array = value as? [Any] {
            let pieces = array.compactMap { extractText(from: $0) }
            return pieces.isEmpty ? nil : pieces.joined(separator: "\n")
        }

        if let dictionary = value as? [String: Any] {
            if let text = dictionary["text"] as? String {
                return text
            }

            if let content = dictionary["content"] {
                return extractText(from: content)
            }

            if let output = dictionary["output"] {
                return extractText(from: output)
            }
        }

        return nil
    }
}
