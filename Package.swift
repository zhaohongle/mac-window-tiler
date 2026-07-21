// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WindowTiler",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WindowTiler",
            path: "Sources"
        )
    ]
)
