// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "aranetctl",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // Library product for AranetKit
        .library(
            name: "AranetKit",
            targets: ["AranetKit"]
        ),
        // Executable product for the CLI
        .executable(
            name: "aranetctl",
            targets: ["aranetctl"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")
    ],
    targets: [
        // Library target containing core Aranet functionality
        .target(
            name: "AranetKit",
            dependencies: []
        ),
        // Executable target for the CLI application
        .executableTarget(
            name: "aranetctl",
            dependencies: [
                "AranetKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
