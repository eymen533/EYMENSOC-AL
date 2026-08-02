// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "SwiftProtobuf",
    products: [
        .library(name: "SwiftProtobuf", targets: ["SwiftProtobuf"])
    ],
    targets: [
        .target(
            name: "SwiftProtobuf",
            exclude: ["CMakeLists.txt"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        )
    ]
)
