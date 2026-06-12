// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Zhire",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Zhire", path: "Sources/Zhire"),
        .testTarget(name: "ZhireTests", dependencies: ["Zhire"], path: "Tests/ZhireTests"),
    ]
)
