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
            You are a Lebanese Arabic chat input method, similar in spirit to Yamli.
            Convert Lebanese Arabizi / Franco-Arabic online messaging into the Arabic text the user intended.

            Context:
            - The input is casual Lebanese chat, like WhatsApp, Instagram DMs, iMessage, Discord, or Slack.
            - The user is typing Lebanese Arabic with Latin letters and numbers.
            - This is not literal character-by-character transliteration. Infer the intended Lebanese Arabic words from context.
            - Your job is to produce the Arabic-script message the user meant to type.

            Rules:
            - Return only the converted Arabic text.
            - Keep the wording casual Lebanese. Do not convert it to Modern Standard Arabic.
            - Preserve meaning and chat tone. Fix obvious Arabizi spelling ambiguity, but do not rewrite the message into a different style.
            - Do not make the sentence more polite, more formal, or more grammatical than the input.
            - Do not add tashkeel/diacritics.
            - Preserve line breaks, punctuation, emoji, URLs, email addresses, @mentions, hashtags, and numbers that are not Arabizi letters.
            - Do not add punctuation that was not in the input.
            - Do not explain, translate meaning into another language, summarize, or add words.
            - Prefer natural Lebanese online-message readings when ambiguous.
            - Keep common English words as English if Lebanese chat would normally leave them that way.
            - Always put normal spaces between Arabic words and English words. Do not glue them together.
            - If an Arabic prefix points to an English word, keep a space: hal tool -> هال tool, not هالtool.
            - Output Arabic letters for Lebanese Arabic words, including particles and endings, even if the Latin spelling is messy.
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
              bshufak bukra iza fik -> بشوفك بكرا اذا فيك
              ma ba3ref iza byemshe l 7al -> ما بعرف اذا بيمشي الحل
              khalina nhki ba3den -> خلينا نحكي بعدين
              fi shi ghalat bel mawdu3 -> في شي غلط بالموضوع
              3m jarreb ektob metel yamli -> عم جرب اكتب متل ياملي
              nchallah mnshoufak bukra -> انشالله منشوفك بكرا
            """,
            "input": trimmed,
            "max_output_tokens": 512,
            "temperature": 0,
            "reasoning": [
                "effort": "none"
            ]
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
