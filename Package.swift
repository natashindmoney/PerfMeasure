// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios-INDProfiler",
    platforms: [.macOS(.v10_15), .iOS(.v17), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "INDProfiler",
            targets: ["INDProfiler"]
        ),
    ],
    targets: [
        .target(
            name: "INDProfiler",
            dependencies: [],
            path: "Sources/INDProfiler"
        ),
        .testTarget(
            name: "INDProfilerTests",
            dependencies: ["INDProfiler"]
        ),
    ]
)
