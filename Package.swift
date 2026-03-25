// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "HarbourMaster",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "HarbourMaster",
            path: "Sources/HarbourMaster"
        )
    ]
)
