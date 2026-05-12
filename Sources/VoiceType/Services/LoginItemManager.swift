import Foundation

enum LoginItemManager {
    private static let identifier = "com.ammarcodex.voicetype.launch"
    private static let installedAppPath = "/Applications/VoiceType.app"

    private static var launchAgentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
    }

    private static var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(identifier).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        try unloadIfNeeded()

        if enabled {
            try FileManager.default.createDirectory(
                at: launchAgentsDirectory,
                withIntermediateDirectories: true
            )

            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(identifier)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/usr/bin/open</string>
                    <string>\(launchAppPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """

            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            try load()
        } else if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    private static var launchAppPath: String {
        if FileManager.default.fileExists(atPath: installedAppPath) {
            return installedAppPath
        }

        return Bundle.main.bundlePath
    }

    private static func load() throws {
        try runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    private static func unloadIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            return
        }

        do {
            try runLaunchctl(arguments: ["bootout", "gui/\(getuid())/\(identifier)"])
        } catch {
            try? runLaunchctl(arguments: ["bootout", "gui/\(getuid())", plistURL.path])
        }
    }

    private static func runLaunchctl(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "LoginItemManager",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "launchctl \(arguments.joined(separator: " ")) failed"]
            )
        }
    }
}
