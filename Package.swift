// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LiveWall",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "LiveWall",
            path: "Sources/LiveWall"
        )
    ]
)
