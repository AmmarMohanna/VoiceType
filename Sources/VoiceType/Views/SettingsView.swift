import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: DictationController
    @State private var apiKeyDraft = ""
    @State private var apiKeyMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mode")
                    .font(.headline)

                Picker("Mode", selection: modeBinding) {
                    ForEach(DictationMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(controller.mode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Language")
                    .font(.headline)

                TextField("en", text: languageBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Text("Use ISO language codes like en, ar, fr, or leave blank.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Start at login", isOn: launchAtLoginBinding)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("API key")
                        .font(.headline)
                    Spacer()
                    Text(AppSecrets.resolvedOpenAIAPIKey.isEmpty ? "Missing" : "Configured")
                        .font(.caption)
                        .foregroundStyle(AppSecrets.resolvedOpenAIAPIKey.isEmpty ? .red : .secondary)
                }

                HStack(spacing: 8) {
                    SecureField("sk-...", text: $apiKeyDraft)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        saveAPIKey()
                    }
                }

                Text(apiKeyMessage.isEmpty ? "Stored locally in macOS Keychain." : apiKeyMessage)
                    .font(.caption)
                    .foregroundStyle(apiKeyMessage.hasPrefix("Error") ? .red : .secondary)
            }
        }
        .padding(20)
        .frame(width: 430, height: 350, alignment: .topLeading)
        .onAppear {
            apiKeyDraft = KeychainStore.readOpenAIAPIKey()
        }
    }

    private var modeBinding: Binding<DictationMode> {
        Binding {
            controller.mode
        } set: { newValue in
            controller.setMode(newValue)
        }
    }

    private var languageBinding: Binding<String> {
        Binding {
            controller.languageHint
        } set: { newValue in
            controller.setLanguageHint(newValue)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            controller.launchAtLogin
        } set: { newValue in
            controller.setLaunchAtLogin(newValue)
        }
    }

    private func saveAPIKey() {
        do {
            try KeychainStore.saveOpenAIAPIKey(apiKeyDraft)
            apiKeyMessage = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "API key cleared."
                : "API key saved."
        } catch {
            apiKeyMessage = "Error: \(error.localizedDescription)"
        }
    }
}
