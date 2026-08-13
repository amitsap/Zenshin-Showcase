// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ZenshinShowcase",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ZenshinShowcase", targets: ["ZenshinShowcase"]),
    ],
    targets: [
        .target(name: "ZenshinShowcase"),
        .testTarget(name: "ZenshinShowcaseTests", dependencies: ["ZenshinShowcase"]),
    ]
)
