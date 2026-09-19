// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ForgeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ForgeCore", targets: ["ForgeCore"]),
    ],
    targets: [
        .target(
            name: "ForgeCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ForgeCoreTests",
            dependencies: ["ForgeCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
