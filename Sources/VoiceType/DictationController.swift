import AppKit
import Foundation

@MainActor
final class DictationController: ObservableObject {
    static let shared = DictationController()

    @Published var isRecording = false
    @Published var isFinishing = false
    @Published var isStartingAudioRecording = false
    @Published var isAudioRecording = false
    @Published var transcript = ""
    @Published var status = "Ready"
    @Published var errorMessage: String?
    @Published var lastCopiedAt: Date?
    @Published var lastAudioRecordingURL: URL?
    @Published var mode: DictationMode
    @Published var languageHint: String
    @Published var launchAtLogin: Bool

    private let audioCapture = AudioCaptureService()
    private let audioRecorder = AudioRecordingService()
    private var transcriber: OpenAIRealtimeTranscriber?

    private init() {
        let defaults = UserDefaults.standard
        mode = .fast
        defaults.set(DictationMode.fast.rawValue, forKey: DefaultsKey.mode)
        languageHint = defaults.string(forKey: DefaultsKey.languageHint) ?? "en"
        launchAtLogin = LoginItemManager.isEnabled
    }

    func configureHotkey() {
        HotkeyManager.shared.registerOptionSpace { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }

        HotkeyManager.shared.registerControlR { [weak self] in
            Task { @MainActor in
                self?.toggleAudioRecording()
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

        guard !isStartingAudioRecording, !isAudioRecording else {
            errorMessage = "Stop audio recording before starting dictation."
            status = "Audio Recording"
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
            let finalText = await transcriber?.finishAndClose() ?? transcript
            transcriber = nil

            transcript = finalText
            copyCurrentTranscript()
            isFinishing = false
            status = finalText.isEmpty ? "Ready" : "Copied"
        }
    }

    func toggleAudioRecording() {
        guard !isStartingAudioRecording else {
            return
        }

        if isAudioRecording {
            stopAudioRecording()
        } else {
            startAudioRecording()
        }
    }

    func startAudioRecording() {
        guard !isStartingAudioRecording, !isAudioRecording else {
            return
        }

        guard !isRecording, !isFinishing else {
            errorMessage = "Stop dictation before starting audio recording."
            return
        }

        errorMessage = nil
        isStartingAudioRecording = true
        status = "Preparing Audio"

        Task {
            do {
                lastAudioRecordingURL = try await audioRecorder.start()
                isStartingAudioRecording = false
                isAudioRecording = true
                status = "Audio Recording"
            } catch {
                isStartingAudioRecording = false
                isAudioRecording = false
                errorMessage = error.localizedDescription
                status = "Error"
            }
        }
    }

    func stopAudioRecording() {
        guard isAudioRecording else {
            return
        }

        lastAudioRecordingURL = audioRecorder.stop()
        isAudioRecording = false
        status = lastAudioRecordingURL == nil ? "Ready" : "Audio Saved"
    }

    func revealLastAudioRecording() {
        guard let lastAudioRecordingURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([lastAudioRecordingURL])
    }

    func copyCurrentTranscript() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        ClipboardService.copy(text)
        lastCopiedAt = Date()
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
