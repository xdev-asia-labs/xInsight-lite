// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "xInsight-lite",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "xInsight-lite", targets: ["xInsight"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "xInsight",
            dependencies: [],
            path: "xInsight",
            exclude: ["Resources/Assets.xcassets"],
            resources: [
                .copy("../Resources/en.lproj"),
                .copy("../Resources/vi.lproj")
            ]
        ),
        .testTarget(
            name: "xInsightTests",
            dependencies: ["xInsight"],
            path: "Tests/xInsightTests"
        )
    ]
)
