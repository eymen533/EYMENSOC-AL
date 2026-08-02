// swift-tools-version: 5.9

// Swift Playgrounds / Xcode App Playground manifest.
// Open this folder (SOC.swiftpm) in Swift Playgrounds on iPad.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "SOC",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "SOC",
            targets: ["AppModule"],
            bundleIdentifier: "com.eymenisin.soc",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
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
                    purposeString: "SOC, aracınızla Bluetooth üzerinden yerel olarak iletişim kurmak için Bluetooth kullanır."
                ),
                .locationWhenInUse(
                    purposeString: "SOC, harita ve navigasyon görünümü için konumunuzu kullanır."
                )
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/misakatao/TeslaBLEKeyKit.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "TeslaBLEKeyKit", package: "TeslaBLEKeyKit")
            ],
            path: ".",
            exclude: ["Package.swift"],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
