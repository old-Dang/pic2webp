// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pic2webp",
    platforms: [.macOS(.v14)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "pic2webp",
            path: "Sources/Pic2WebP",
            resources: [
                .copy("Resources"),
                .process("Assets.xcassets"),
            ]
        )
    ]
)
