import Foundation

enum AppSecrets {
    // Keep this blank in source control. Use Settings or OPENAI_API_KEY instead.
    static let openAIAPIKey = ""

    static var resolvedOpenAIAPIKey: String {
        let environmentKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if !environmentKey.isEmpty {
            return environmentKey
        }

        let keychainKey = KeychainStore.readOpenAIAPIKey()
        if !keychainKey.isEmpty {
            return keychainKey
        }

        return openAIAPIKey
    }
}
