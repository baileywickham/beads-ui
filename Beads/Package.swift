// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Beads",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Beads", targets: ["Beads"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Beads",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Beads",
            exclude: ["Assets.xcassets"]
        ),
    ]
)
