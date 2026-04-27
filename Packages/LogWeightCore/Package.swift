// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LogWeightCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LogWeightCore",
            targets: ["LogWeightCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LogWeightCore",
            dependencies: [],
            path: "Sources/LogWeightCore"
        ),
        .testTarget(
            name: "LogWeightCoreTests",
            dependencies: ["LogWeightCore"],
            path: "Tests/LogWeightCoreTests"
        )
    ]
)
