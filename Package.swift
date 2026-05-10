// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VoiceType",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VoiceType", targets: ["VoiceType"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceType",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WebKit")
            ]
        )
    ]
)
