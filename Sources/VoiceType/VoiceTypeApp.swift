import AppKit
import SwiftUI

@main
struct VoiceTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = DictationController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller)
        } label: {
            Image(systemName: controller.isRecording ? "mic.fill" : "mic")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            DictationController.shared.configureHotkey()
        }

        if ProcessInfo.processInfo.environment["VOICETYPE_OPEN_SETTINGS_ON_LAUNCH"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task { @MainActor in
                    SettingsWindowController.shared.show(controller: DictationController.shared)
                }
            }
        }
    }
}
