// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iMonet",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "iMonet",
            dependencies: [
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "iMonetTests",
            dependencies: ["iMonet"]
        ),
    ]
)
