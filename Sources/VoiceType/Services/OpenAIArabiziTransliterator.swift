import Foundation

enum OpenAIArabiziTransliterator {
    static func convert(_ input: String, apiKey: String, model: String) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "instructions": """
            Convert Lebanese Arabizi / Franco-Arabic online messaging into Arabic script.

            Context:
            - The input is casual Lebanese chat, like WhatsApp, Instagram DMs, iMessage, Discord, or Slack.
            - The user is typing Lebanese Arabic with Latin letters and numbers.
            - Your job is transliteration into Arabic letters, not translation and not formal rewriting.

            Rules:
            - Return only the converted Arabic text.
            - Keep the wording casual Lebanese. Do not convert it to Modern Standard Arabic.
            - Convert script only. Do not make the sentence more polite, more formal, or more grammatical than the input.
            - Do not add tashkeel/diacritics.
            - Preserve line breaks, punctuation, emoji, URLs, email addresses, @mentions, hashtags, and numbers that are not Arabizi letters.
            - Do not add punctuation that was not in the input.
            - Do not explain, translate meaning into another language, summarize, or add words.
            - Prefer natural Lebanese online-message readings when ambiguous.
            - Keep common English words as English if Lebanese chat would normally leave them that way.
            - Common mappings include: 2=ء/ق depending on word, 3=ع, 5/7'=خ, 6=ط, 6'=ظ, 7=ح, 8/9=ق when appropriate, 9=ص, kh=خ, gh=غ, sh=ش, th=ث, dh=ذ.
            - Examples:
              kifak -> كيفك
              kifkon -> كيفكن
              kifik -> كيفك
              shu baddak -> شو بدك
              shu badde -> شو بدي
              ana ma badde -> انا ما بدي
              3am ekteb 3arabi -> عم اكتب عربي
              7abibi khaberni -> حبيبي خبرني
              ma3ak 7a2 -> معك حق
              halla2 -> هلأ
              shu baddak menne halla2 -> شو بدك مني هلأ
              ma tensa teb3atle -> ما تنسى تبعتلي
              leh hek 3am ta3mol -> ليه هيك عم تعمل
              mesh 3aref shu sar -> مش عارف شو صار
              ba3tik later -> بعطيك later
              nchallah mnshoufak bukra -> انشالله منشوفك بكرا
            """,
            "input": trimmed,
            "max_output_tokens": 512,
            "temperature": 0
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw NSError(
                domain: "OpenAIArabiziTransliterator",
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

        return ""
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
