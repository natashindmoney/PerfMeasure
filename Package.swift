// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PerfMeasureMacros",
    platforms: [
        .iOS(.v17),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "PerfMeasure",
            targets: ["PerfMeasure"]
        ),
        // The client library that exposes the macros
        .library(
            name: "PerfMeasureClient",
            targets: ["PerfMeasureClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        // Main runtime target
        .target(
            name: "PerfMeasure",
            dependencies: [],
            path: "Sources/PerfMeasure"
        ),

        // Macro implementation that performs source transformations
        .macro(
            name: "PerfMeasureMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Client library that exposes the macros to user code
        .target(
            name: "PerfMeasureClient",
            dependencies: ["PerfMeasureMacros"]
        ),

        // Tests for the macros
        .testTarget(
            name: "PerfMeasureMacrosTests",
            dependencies: [
                "PerfMeasureMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
