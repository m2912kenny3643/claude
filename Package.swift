// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeGuide",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ClaudeGuide", path: "Sources/ClaudeGuide")
    ]
)
