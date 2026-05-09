import Foundation

enum AppSecrets {
    // Keep this blank in source control. Use .env or OPENAI_API_KEY instead.
    static let openAIAPIKey = ""

    static var resolvedOpenAIAPIKey: String {
        let environmentKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if !environmentKey.isEmpty {
            return environmentKey
        }

        if let dotenvKey = Dotenv.openAIAPIKey(), !dotenvKey.isEmpty {
            return dotenvKey
        }

        return openAIAPIKey
    }
}

private enum Dotenv {
    static func openAIAPIKey() -> String? {
        for url in candidateURLs() {
            guard let value = value(named: "OPENAI_API_KEY", in: url), !value.isEmpty else {
                continue
            }

            return value
        }

        return nil
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent(".env"))
        }

        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env"))

        if let executableURL = Bundle.main.executableURL {
            urls.append(executableURL.deletingLastPathComponent().appendingPathComponent(".env"))
        }

        urls.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".voicetype")
                .appendingPathComponent(".env")
        )

        return urls
    }

    private static func value(named name: String, in url: URL) -> String? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            let pieces = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2,
                  pieces[0].trimmingCharacters(in: .whitespacesAndNewlines) == name else {
                continue
            }

            return clean(String(pieces[1]))
        }

        return nil
    }

    private static func clean(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count >= 2,
           let first = cleaned.first,
           let last = cleaned.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            cleaned.removeFirst()
            cleaned.removeLast()
        }

        return cleaned
    }
}
