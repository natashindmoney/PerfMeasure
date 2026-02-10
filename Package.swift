// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios-INDProfiler",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
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
