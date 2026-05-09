import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: DictationController
    @State private var selectedTab: MenuTab = .voice
    @State private var arabiziInput = ""
    @State private var arabiziOutput = ""

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

            Text(selectedTab == .voice ? controller.mode.label : "Arabizi")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorMessage = controller.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("Option-Space toggles recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    controller.clearTranscript()
                }
                .buttonStyle(.plain)
                .disabled(controller.transcript.isEmpty && controller.errorMessage == nil)
            }
        }
    }

    private var arabiziContent: some View {
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
                    updateArabiziOutput()
                }

            ScrollView {
                Text(arabiziOutput.isEmpty ? "اكتب Arabizi فوق..." : arabiziOutput)
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

            HStack(spacing: 8) {
                Button {
                    updateArabiziOutput()
                } label: {
                    Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    copyArabiziOutput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .disabled(arabiziOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    clearArabizi()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 30)
                }
                .help("Clear")
            }

            Text("Examples: kifak, shu baddak, 3arabi, 7abibi, khaberni.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var transcriptText: String {
        if !controller.transcript.isEmpty {
            return controller.transcript
        }

        if controller.isRecording {
            return "Listening..."
        }

        return "Your transcript will appear here."
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

    private var statusColor: Color {
        if controller.isRecording {
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

    private func updateArabiziOutput() {
        arabiziOutput = ArabiziTransliterator.convert(arabiziInput)
    }

    private func copyArabiziOutput() {
        let text = arabiziOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        ClipboardService.copy(text)
    }

    private func clearArabizi() {
        arabiziInput = ""
        arabiziOutput = ""
    }
}

private enum MenuTab {
    case voice
    case arabizi
}
