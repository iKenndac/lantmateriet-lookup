// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "lantmateriet-generator",
    dependencies: [
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.1.0"),
        ],
    targets: [
        .target(name: "lantmateriet-generator", dependencies: ["Utility"]),
        ]
)
