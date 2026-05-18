import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: DictationController
    @State private var selectedTab: MenuTab = .voice
    @State private var arabiziInput = ""
    @State private var arabiziOutput = ""
    @State private var arabiziStatus = ""
    @State private var isArabiziRefining = false
    @State private var isArabiziImproving = false
    @State private var arabiziConversionTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            tabPicker

            switch selectedTab {
            case .voice:
                voiceContent
            case .arabizi:
                arabiziContent
            }
        }
        .padding(14)
        .frame(width: 390)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VoiceType")
                    .font(.headline)
                Text(controller.status)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()
        }
    }

    private var tabPicker: some View {
        Picker("Tool", selection: $selectedTab) {
            Label("Voice", systemImage: "mic").tag(MenuTab.voice)
            Label("Arabizi", systemImage: "character.cursor.ibeam").tag(MenuTab.arabizi)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var voiceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            transcriptView
            controls
            audioRecordingControls
            footer
        }
    }

    private var transcriptView: some View {
        ScrollView {
            Text(transcriptText)
                .font(.body)
                .foregroundStyle(controller.transcript.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(10)
        }
        .frame(height: 150)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                controller.toggleRecording()
            } label: {
                Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.space, modifiers: [.option])
            .disabled(controller.isFinishing)

            Button {
                controller.copyCurrentTranscript()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .disabled(controller.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 30)
            }
            .help("Settings")
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let errorMessage = controller.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var audioRecordingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 8) {
                Button {
                    controller.toggleAudioRecording()
                } label: {
                    Label(audioRecordingButtonTitle, systemImage: audioRecordingButtonIcon)
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("r", modifiers: [.control])
                .disabled(
                    controller.isStartingAudioRecording
                        || (!controller.isAudioRecording && (controller.isRecording || controller.isFinishing))
                )

                if controller.lastAudioRecordingURL != nil && !controller.isAudioRecording {
                    Button {
                        controller.revealLastAudioRecording()
                    } label: {
                        Label("Reveal", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Text(audioRecordingStatusText)
                .font(.caption)
                .foregroundStyle(audioRecordingStatusColor)
                .lineLimit(1)
        }
    }

    private var arabiziContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            arabiziEditor

            HStack(spacing: 8) {
                Button {
                    clearArabizi()
                } label: {
                    Label("Clear", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .disabled(arabiziInput.isEmpty && arabiziOutput.isEmpty && arabiziStatus.isEmpty)

                Button {
                    copyArabiziOutput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .disabled(arabiziOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    showSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .frame(width: 30)
                }
                .help("Settings")
            }

            Button {
                improveArabiziWithLLM()
            } label: {
                Label("Improve with LLM", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .disabled(arabiziOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isArabiziImproving)

            HStack(spacing: 6) {
                if isArabiziRefining || isArabiziImproving {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.65)
                }

                Text(arabiziFooterText)
                    .font(.caption)
                    .foregroundStyle(arabiziFooterColor)
            }
        }
    }

    private var arabiziEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $arabiziInput)
                .font(.body)
                .frame(height: 92)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                }
                .onChange(of: arabiziInput) { _ in
                    scheduleArabiziConversion()
                }

            ScrollView {
                Text(arabiziOutput.isEmpty ? "اكتب Arabizi فوق..." : formattedArabiziOutput)
                    .font(.title3)
                    .foregroundStyle(arabiziOutput.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .textSelection(.enabled)
                    .padding(10)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .frame(height: 92)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            }
        }
    }

    private var transcriptText: String {
        if !controller.transcript.isEmpty {
            return controller.transcript
        }

        if controller.isRecording {
            return "Listening..."
        }

        return "Press Option-Space to dictate."
    }

    private var primaryButtonTitle: String {
        if controller.isRecording {
            return "Stop"
        }

        if controller.isFinishing {
            return "Finishing"
        }

        return "Start"
    }

    private var primaryButtonIcon: String {
        controller.isRecording ? "stop.fill" : "mic.fill"
    }

    private var audioRecordingButtonTitle: String {
        if controller.isStartingAudioRecording {
            return "Starting"
        }

        return controller.isAudioRecording ? "Stop Audio" : "Record Audio"
    }

    private var audioRecordingButtonIcon: String {
        controller.isAudioRecording ? "stop.circle.fill" : "record.circle"
    }

    private var audioRecordingStatusText: String {
        if controller.isStartingAudioRecording {
            return "Preparing microphone..."
        }

        if controller.isAudioRecording {
            return "Recording..."
        }

        if let lastAudioRecordingURL = controller.lastAudioRecordingURL {
            return "Saved \(lastAudioRecordingURL.lastPathComponent)"
        }

        return "Control-R to record audio."
    }

    private var audioRecordingStatusColor: Color {
        controller.isAudioRecording ? .red : .secondary
    }

    private var statusColor: Color {
        if controller.isRecording || controller.isAudioRecording {
            return .red
        }

        if controller.errorMessage != nil {
            return .red
        }

        return .secondary
    }

    private func showSettings() {
        SettingsWindowController.shared.show(controller: controller)
    }

    private var arabiziFooterText: String {
        if !arabiziStatus.isEmpty {
            return arabiziStatus
        }

        return "Yamli converts after 0.5s. Improve with LLM only when needed."
    }

    private var arabiziFooterColor: Color {
        let lowercasedStatus = arabiziStatus.lowercased()
        if lowercasedStatus.contains("missing")
            || lowercasedStatus.contains("failed")
            || lowercasedStatus.contains("unavailable") {
            return .red
        }

        return .secondary
    }

    private var formattedArabiziOutput: String {
        BidiTextFormatter.prepareMixedArabicEnglish(arabiziOutput)
    }

    private func scheduleArabiziConversion() {
        updateArabiziOutput()
        arabiziConversionTask?.cancel()

        let input = arabiziInput
        arabiziConversionTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await convertArabiziWithYamli(input)
        }
    }

    private func updateArabiziOutput() {
        arabiziOutput = ArabiziTransliterator.convert(arabiziInput)
        arabiziStatus = ""
    }

    @MainActor
    private func convertArabiziWithYamli(_ input: String) async {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            arabiziOutput = ""
            arabiziStatus = ""
            isArabiziRefining = false
            return
        }

        isArabiziRefining = true
        arabiziStatus = "Yamli converting..."

        do {
            let converted = try await YamliTransliterator.convert(trimmedInput)

            guard !Task.isCancelled, trimmedInput == arabiziInput.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }

            if !converted.isEmpty {
                arabiziOutput = converted
            }
            arabiziStatus = ""
            isArabiziRefining = false
        } catch {
            guard !Task.isCancelled else {
                return
            }

            arabiziStatus = "Yamli unavailable; using LLM fallback..."
            await refineArabizi(input)
        }
    }

    @MainActor
    private func refineArabizi(_ input: String) async {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            arabiziOutput = ""
            arabiziStatus = ""
            isArabiziRefining = false
            return
        }

        let apiKey = AppSecrets.resolvedOpenAIAPIKey
        guard !apiKey.isEmpty else {
            arabiziStatus = "Missing API key; showing local conversion."
            isArabiziRefining = false
            return
        }

        isArabiziRefining = true
        arabiziStatus = "LLM refining with \(AppSecrets.arabiziModel)..."

        do {
            let refined = try await OpenAIArabiziTransliterator.convert(
                trimmedInput,
                apiKey: apiKey,
                model: AppSecrets.arabiziModel
            )

            guard !Task.isCancelled, trimmedInput == arabiziInput.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }

            if !refined.isEmpty {
                arabiziOutput = refined
            }
            arabiziStatus = ""
        } catch {
            guard !Task.isCancelled else {
                return
            }

            arabiziStatus = "LLM unavailable; showing local conversion."
        }

        isArabiziRefining = false
    }

    private func improveArabiziWithLLM() {
        arabiziConversionTask?.cancel()

        let text = arabiziOutput
        arabiziConversionTask = Task {
            await improveArabizi(text)
        }
    }

    @MainActor
    private func improveArabizi(_ input: String) async {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return
        }

        let apiKey = AppSecrets.resolvedOpenAIAPIKey
        guard !apiKey.isEmpty else {
            arabiziStatus = "Missing API key; cannot improve with LLM."
            return
        }

        isArabiziImproving = true
        arabiziStatus = "Improving with \(AppSecrets.arabiziImproveModel)..."

        do {
            let improved = try await OpenAIArabiziTransliterator.improve(
                trimmedInput,
                apiKey: apiKey,
                model: AppSecrets.arabiziImproveModel
            )

            guard !Task.isCancelled else {
                return
            }

            if !improved.isEmpty {
                arabiziOutput = improved
            }
            arabiziStatus = ""
        } catch {
            guard !Task.isCancelled else {
                return
            }

            arabiziStatus = "Improve failed; keeping current text."
        }

        isArabiziImproving = false
    }

    private func copyArabiziOutput() {
        let text = formattedArabiziOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        ClipboardService.copy(text)
    }

    private func clearArabizi() {
        arabiziConversionTask?.cancel()
        arabiziInput = ""
        arabiziOutput = ""
        arabiziStatus = ""
        isArabiziRefining = false
        isArabiziImproving = false
    }
}

private enum MenuTab {
    case voice
    case arabizi
}
