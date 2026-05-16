// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Monet",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern.git", from: "1.1.0"),
        .package(url: "https://github.com/quassum/SwiftUI-Tooltip.git", from: "1.3.1"),
    ],
    targets: [
        .executableTarget(
            name: "Monet",
            dependencies: [
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "SwiftUITooltip", package: "SwiftUI-Tooltip"),
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MonetTests",
            dependencies: ["Monet"]
        ),
    ]
)
