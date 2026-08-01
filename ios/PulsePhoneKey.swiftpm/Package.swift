// swift-tools-version: 5.9
//
// Swift Playgrounds (iPad) App project — open this folder in Swift Playgrounds.
// Bluetooth privacy strings come from Info.plist via additionalInfoPlistContentFilePath.

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
            displayVersion: "1.0",
            bundleVersion: "1",
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
            additionalInfoPlistContentFilePath: "Info.plist"
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)
