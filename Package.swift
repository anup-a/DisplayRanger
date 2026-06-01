// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DisplayRanger",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DisplayRanger",
            path: "Sources/DisplayRanger"
        )
    ]
)
