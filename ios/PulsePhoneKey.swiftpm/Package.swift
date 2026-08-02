// swift-tools-version: 5.9
//
// IMPORTANT: Bluetooth permission must be declared via `capabilities`
// (Playgrounds-native). Info.plist alone is often ignored → iOS kills the app.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "PulsePhoneKey",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "PulsePhoneKey",
            targets: ["AppModule"],
            bundleIdentifier: "com.teslapulse.phonekey",
            teamIdentifier: "",
            displayVersion: "4.2",
            bundleVersion: "42",
            appIcon: .placeholder(icon: .car),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .bluetoothAlways(
                    purposeString: "Tesla Phone Key eslesmesi icin Bluetooth gerekir."
                )
            ],
            additionalInfoPlistContentFilePath: "Info.plist"
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            exclude: [
                "Package.swift",
                "Info.plist",
                "PLAYGROUNDS.md",
                "CRASH_FIX.md",
                "MANUAL.md",
                "IPHONE.md"
            ]
        )
    ]
)
