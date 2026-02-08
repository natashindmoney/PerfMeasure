// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Swift Version Compatibility:
// - Swift 5.9+: Supports #measured/#measuredAsync expression macros and helper functions
// - Swift 6.0+: Additionally supports @Measured body macro
//
// Body macros (@attached(body)) require Swift 6.0+ (SE-0415)

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PerfMeasure",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Core runtime library with PerfMeasure API
        .library(
            name: "PerfMeasure",
            targets: ["PerfMeasure"]
        ),
        // Client library that exposes macros and re-exports PerfMeasure
        // Use this for the simplest integration - just `import PerfMeasureClient`
        .library(
            name: "PerfMeasureClient",
            targets: ["PerfMeasureClient"]
        ),
    ],
    dependencies: [
        // swift-syntax 509.x for Swift 5.9, 510.x for Swift 5.10, 600.x for Swift 6.0
        // SPM will resolve to the appropriate version based on the Swift toolchain
        .package(url: "https://github.com/apple/swift-syntax.git", "509.0.0"..<"700.0.0"),
    ],
    targets: [
        // Main runtime target with all measurement functionality
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

        // Client library that exposes the macros and re-exports PerfMeasure types
        // This is the recommended import for most users
        .target(
            name: "PerfMeasureClient",
            dependencies: [
                "PerfMeasure",
                "PerfMeasureMacros"
            ]
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
