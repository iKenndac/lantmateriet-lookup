// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "lantmateriet-lookup",
    dependencies: [
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.1.0"),
        ],
    targets: [
        .target(name: "lantmateriet-lookup", dependencies: ["Utility"]),
        ]
)
