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
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "BeadsLib",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Beads",
            exclude: ["Assets.xcassets", "Info.plist", "BeadsApp.swift"]
        ),
        .executableTarget(
            name: "Beads",
            dependencies: [
                "BeadsLib",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Beads",
            exclude: ["Assets.xcassets", "Info.plist", "State", "Data", "Models", "Views", "Commands"],
            sources: ["BeadsApp.swift"]
        ),
        .testTarget(
            name: "BeadsTests",
            dependencies: [
                "BeadsLib",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests"
        ),
    ]
)
