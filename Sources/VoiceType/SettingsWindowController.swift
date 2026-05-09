import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show(controller: DictationController) {
        if window == nil {
            let hostingController = NSHostingController(
                rootView: SettingsView(controller: controller)
            )

            let window = NSWindow(contentViewController: hostingController)
            window.title = "VoiceType Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 430, height: 350))
            window.contentMinSize = NSSize(width: 430, height: 350)
            window.contentMaxSize = NSSize(width: 430, height: 350)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
