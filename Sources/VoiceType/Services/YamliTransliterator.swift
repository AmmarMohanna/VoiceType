import Foundation

enum YamliTransliterator {
    private static let initialBuild = "5515"
    private static let cache = YamliWordCache()
    private static let lebaneseOverrides: [String: String] = [
        "ahla": "احلى",
        "eno": "انو",
        "enno": "انو",
        "ino": "انو",
        "hal": "هال",
        "halla2": "هلأ",
        "hala2": "هلأ",
        "ma3": "مع",
        "3am": "عم"
    ]

    private static let englishWords: Set<String> = [
        "ai", "api", "app", "apps", "bug", "bugs", "call", "chat", "code", "commit",
        "css", "data", "debug", "demo", "design", "dev", "email", "file", "files",
        "git", "github", "html", "idea", "ios", "iphone", "json", "later", "link",
        "llm", "login", "mac", "macos", "meeting", "model", "note", "notes", "openai",
        "and", "are", "as", "at", "by", "for", "from", "in", "is", "it", "me",
        "my", "no", "of", "ok", "okay", "on", "or", "our", "page", "pages", "pdf",
        "pr", "prompt", "repo", "server", "she", "slack", "swift", "task", "team",
        "test", "tests", "text", "that", "the", "their", "these", "they", "this",
        "those", "to", "tool", "tools", "ui", "url", "user", "users", "voice",
        "was", "we", "web", "were", "with", "without", "work", "xcode", "yes", "you",
        "your", "its"
    ]

    static func convert(_ input: String) async throws -> String {
        let parts = splitKeepingSeparators(input)
        var output = ""

        for part in parts {
            if shouldConvert(part) {
                output += try await convertWord(part)
            } else {
                output += part
            }
        }

        return output
    }

    private static func shouldConvert(_ part: String) -> Bool {
        let normalized = normalizedWord(part)
        guard !normalized.isEmpty,
              normalized.contains(where: { $0.isLetter || $0.isNumber }),
              normalized.contains(where: { $0.isASCII }) else {
            return false
        }

        if englishWords.contains(normalized) {
            return false
        }

        return true
    }

    private static func convertWord(_ word: String) async throws -> String {
        let normalized = normalizedWord(word)

        if let override = lebaneseOverrides[normalized] {
            return applyPunctuation(from: word, converted: override)
        }

        if let cached = await cache.value(for: normalized) {
            return applyPunctuation(from: word, converted: cached)
        }

        let converted = try await requestWord(normalized, build: initialBuild)
        await cache.set(converted, for: normalized)

        return applyPunctuation(from: word, converted: converted)
    }

    private static func requestWord(_ word: String, build: String) async throws -> String {
        var components = URLComponents(string: "https://api.yamli.com/transliterate.ashx")!
        components.queryItems = [
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "tool", value: "api"),
            URLQueryItem(name: "account_id", value: ""),
            URLQueryItem(name: "prot", value: "https:"),
            URLQueryItem(name: "hostname", value: "www.yamli.com"),
            URLQueryItem(name: "path", value: "/"),
            URLQueryItem(name: "build", value: build)
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "YamliTransliterator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Yamli request failed"]
            )
        }

        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "YamliTransliterator",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Yamli response"]
            )
        }

        if payload["staleClient"] as? Bool == true,
           let serverBuild = payload["serverBuild"] as? String,
           serverBuild != build {
            return try await requestWord(word, build: serverBuild)
        }

        guard let rawResults = payload["r"] as? String,
              !rawResults.isEmpty else {
            return word
        }

        return firstCandidate(from: rawResults) ?? word
    }

    private static func firstCandidate(from rawResults: String) -> String? {
        rawResults
            .split(separator: "|")
            .first?
            .split(separator: "/", maxSplits: 1)
            .first
            .map(String.init)
    }

    private static func splitKeepingSeparators(_ input: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var currentIsWord: Bool?

        for character in input {
            let isWord = character.isLetter || character.isNumber || character == "'" || character == "_"
            if currentIsWord == nil || currentIsWord == isWord {
                current.append(character)
                currentIsWord = isWord
            } else {
                parts.append(current)
                current = String(character)
                currentIsWord = isWord
            }
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    private static func normalizedWord(_ word: String) -> String {
        word.trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
    }

    private static func applyPunctuation(from original: String, converted: String) -> String {
        let leadingCount = original.prefix(while: { $0.isPunctuation }).count
        let trailingCount = original.reversed().prefix(while: { $0.isPunctuation }).count
        return String(original.prefix(leadingCount)) + converted + String(original.suffix(trailingCount))
    }
}

private actor YamliWordCache {
    private var storage: [String: String] = [:]

    func value(for key: String) -> String? {
        storage[key]
    }

    func set(_ value: String, for key: String) {
        storage[key] = value
    }
}
