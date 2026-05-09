import Foundation

@MainActor
final class DictationController: ObservableObject {
    static let shared = DictationController()

    @Published var isRecording = false
    @Published var isFinishing = false
    @Published var transcript = ""
    @Published var status = "Ready"
    @Published var errorMessage: String?
    @Published var lastCopiedAt: Date?
    @Published var mode: DictationMode
    @Published var languageHint: String
    @Published var launchAtLogin: Bool

    private let audioCapture = AudioCaptureService()
    private var transcriber: OpenAIRealtimeTranscriber?

    private init() {
        let defaults = UserDefaults.standard
        let storedMode = defaults.string(forKey: DefaultsKey.mode)
            .flatMap(DictationMode.init(rawValue:))
        mode = storedMode ?? .fast
        languageHint = defaults.string(forKey: DefaultsKey.languageHint) ?? "en"
        launchAtLogin = LoginItemManager.isEnabled
    }

    func configureHotkey() {
        HotkeyManager.shared.registerOptionSpace { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard !isRecording, !isFinishing else {
            return
        }

        errorMessage = nil
        transcript = ""
        status = "Connecting"

        let apiKey = AppSecrets.resolvedOpenAIAPIKey
        let selectedMode = mode
        let selectedLanguage = languageHint

        Task {
            do {
                guard await audioCapture.requestPermission() else {
                    throw AudioCaptureError.microphoneDenied
                }

                let transcriber = OpenAIRealtimeTranscriber(
                    apiKey: apiKey,
                    mode: selectedMode,
                    language: selectedLanguage,
                    onTranscript: { [weak self] text in
                        self?.transcript = text
                    },
                    onStatus: { [weak self] text in
                        self?.status = text
                    },
                    onError: { [weak self] text in
                        self?.errorMessage = text
                        self?.status = "Error"
                        self?.cleanupRecording()
                    }
                )

                self.transcriber = transcriber
                try await transcriber.connect()

                try audioCapture.start { [weak transcriber] data in
                    transcriber?.sendAudio(data)
                }

                isRecording = true
                status = "Recording"
            } catch {
                cleanupRecording()
                errorMessage = error.localizedDescription
                status = "Error"
            }
        }
    }

    func stopRecording() {
        guard isRecording, !isFinishing else {
            return
        }

        isRecording = false
        isFinishing = true
        status = "Finishing"
        audioCapture.stop()

        Task {
            var finalText = await transcriber?.finishAndClose() ?? transcript
            transcriber = nil

            if mode.polishAfterTranscription {
                status = "Polishing"
                do {
                    finalText = try await OpenAITextPolisher.polish(
                        finalText,
                        apiKey: AppSecrets.resolvedOpenAIAPIKey
                    )
                } catch {
                    errorMessage = "Polish failed: \(error.localizedDescription)"
                }
            }

            transcript = finalText
            copyCurrentTranscript()
            isFinishing = false
            status = finalText.isEmpty ? "Ready" : "Copied"
        }
    }

    func copyCurrentTranscript() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        ClipboardService.copy(text)
        lastCopiedAt = Date()
    }

    func clearTranscript() {
        transcript = ""
        errorMessage = nil
        status = "Ready"
    }

    func setMode(_ mode: DictationMode) {
        self.mode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.mode)
    }

    func setLanguageHint(_ languageHint: String) {
        self.languageHint = languageHint
        UserDefaults.standard.set(languageHint, forKey: DefaultsKey.languageHint)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemManager.setEnabled(enabled)
            launchAtLogin = LoginItemManager.isEnabled
        } catch {
            launchAtLogin = LoginItemManager.isEnabled
            errorMessage = error.localizedDescription
            status = "Error"
        }
    }

    private func cleanupRecording() {
        isRecording = false
        isFinishing = false
        audioCapture.stop()
        transcriber?.close()
        transcriber = nil
    }
}

private enum DefaultsKey {
    static let mode = "dictationMode"
    static let languageHint = "languageHint"
}
