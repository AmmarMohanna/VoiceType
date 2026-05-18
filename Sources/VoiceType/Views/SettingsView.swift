import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Language")
                    .font(.headline)

                Spacer()

                TextField("en", text: languageBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
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
            }
        }
        .padding(20)
        .frame(width: 340, height: 150, alignment: .topLeading)
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
}
