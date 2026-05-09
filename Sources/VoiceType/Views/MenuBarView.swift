import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            transcriptView
            controls
            footer
        }
        .padding(14)
        .frame(width: 360)
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

            Text(controller.mode.label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
}
