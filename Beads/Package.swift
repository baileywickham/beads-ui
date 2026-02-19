// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Beads",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Beads", targets: ["Beads"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.8.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "Beads",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Beads",
            exclude: ["Assets.xcassets", "Info.plist"]
        ),
    ]
)
