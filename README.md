# PerfMeasure

PerfMeasure is the INDmoney performance measurement toolkit packaged as a Swift Package. It ships both the runtime instrumentation APIs and the Swift macros that eliminate boilerplate.

## Requirements

- **Swift 5.9+** minimum (for expression macros and helper functions)
- **Swift 6.0+** required for `@Measured` body macro (SE-0415)
- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+ (Xcode 16.0+ for `@Measured`)

## Swift Version Compatibility

| Feature | Swift 5.9 | Swift 6.0+ |
|---------|-----------|------------|
| `@Measured` body macro | ❌ Not available | ✅ Available |
| `#measured` expression macro | ✅ Available | ✅ Available |
| `#measuredAsync` expression macro | ✅ Available | ✅ Available |
| `measured()` helper function | ✅ Available | ✅ Available |
| `measuredAsync()` helper function | ✅ Available | ✅ Available |

### How to Check Your Swift Version

**In Terminal:**
```bash
swift --version
# or
xcrun swift --version
```

**In Xcode:**
- Go to **Xcode → About Xcode** (shows bundled Swift version)
- Or check **Build Settings → Swift Compiler - Language → Swift Language Version**

**Programmatically (compile-time):**
```swift
#if compiler(>=6.0)
// Swift 6.0+ code - can use @Measured
#else
// Swift 5.9 code - use #measured or measured()
#endif
```

## Overview

### Targets

| Target | Description |
|--------|-------------|
| `PerfMeasure` | Runtime measurement framework with all APIs and helper functions. |
| `PerfMeasureMacros` | Macro implementation target. |
| `PerfMeasureClient` | Recommended import - exposes macros and re-exports `PerfMeasure`. |

The runtime and macros share the same package so the app only needs a single SPM dependency.

### Available APIs

| API | Type | Swift Version | Description |
|-----|------|---------------|-------------|
| `@Measured` | Body Macro | 5.10+ | Wraps an entire function with performance measurement |
| `#measured` | Expression Macro | 5.9+ | Measures a sync expression inline |
| `#measuredAsync` | Expression Macro | 5.9+ | Measures an async expression inline |
| `measured()` | Helper Function | 5.9+ | Measures a sync closure |
| `measuredAsync()` | Helper Function | 5.9+ | Measures an async closure |

## Installation

### Add the Package to Your Project

Since the main app uses CocoaPods, you'll need to integrate this SPM package alongside it:

1. In Xcode, go to **File → Add Package Dependencies...**
2. Click **Add Local...** and select the `Packages/PerfMeasureMacros` directory
3. Add `PerfMeasureClient` to your target

Alternatively, add it to your `Package.swift` if you have a mixed CocoaPods/SPM setup:

```swift
dependencies: [
    .package(path: "../Packages/PerfMeasureMacros")
]
```

### Configure Runtime Dependencies

The runtime no longer depends directly on `INDCommon`. Instead, the host app provides integrations via `PerfMeasureDependencies`:

```swift
import PerfMeasure

final class MyFeatureFlagProvider: PerfMeasureFeatureFlagProviding { /* ... */ }
final class MyEventReporter: PerfMeasureEventReporting { /* ... */ }
final class MyAnalyticsWriter: PerfMeasureAnalyticsWriting { /* ... */ }

PerfMeasureDependencies.featureFlagProvider = MyFeatureFlagProvider()
PerfMeasureDependencies.eventReporter = MyEventReporter()
PerfMeasureDependencies.analyticsWriter = MyAnalyticsWriter()
PerfMeasure.shared.reloadFromFeatureFlags()
```

Providing an `analyticsWriter` enables the new `AnalyticsPerfDestination`, which can forward measurements to AutoTracker/EventFileWriter.

## Usage

### Import

```swift
// Recommended: Single import gives you everything
import PerfMeasureClient

// Alternative: Import only runtime (no macros)
import PerfMeasure
```

`PerfMeasureClient` re-exports `PerfMeasure`, so you only need one import.

### @Measured - Function Wrapper (Swift 5.10+ only)

Automatically wraps a function with performance measurement. This is automatically enabled when building with Swift 5.10+.

```swift
// Basic usage
@Measured("loadUserData")
func loadUserData() -> User {
    return fetchUser()
}

// With category and feature
@Measured("fetchStocks", category: "network", feature: "stocks")
func fetchStocks() async throws -> [Stock] {
    return try await api.getStocks()
}

// With PR tracking
@Measured("processPayment", category: "payments", prNumber: "PR-456")
func processPayment(amount: Decimal) -> PaymentResult {
    return processor.process(amount)
}
```

**Expansion:**

```swift
// Before:
@Measured("loadData", category: "network")
func loadData() -> Data {
    return fetchFromAPI()
}

// After expansion:
func loadData() -> Data {
    return PerfMeasure.shared.measure("loadData", category: "network") {
        return fetchFromAPI()
    }.value
}
```

### #measured - Inline Sync Expression

Measure a specific synchronous expression:

```swift
let user = #measured("parseUser", category: "parsing") {
    try JSONDecoder().decode(User.self, from: jsonData)
}

let filtered = #measured("filterStocks", feature: "stocks") {
    stocks.filter { $0.price > 100 }
}
```

### #measuredAsync - Inline Async Expression

Measure a specific asynchronous expression:

```swift
let profile = await #measuredAsync("fetchProfile", category: "network") {
    try await api.getProfile()
}

let data = await #measuredAsync("downloadImage", feature: "media") {
    try await imageLoader.download(url)
}
```

### Helper Functions

Alternative to macros for measuring entire functions:

```swift
import PerfMeasureClient

func loadUserData() -> User {
    return measured("loadUserData", category: "data") {
        fetchUser()
    }
}

func fetchProfile() async throws -> Profile {
    return try await measuredAsync("fetchProfile", category: "network") {
        try await api.getProfile()
    }
}
```

## Parameters

All macros accept the same parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | `String` | Yes (for expression macros) | Name of the measurement |
| `category` | `String?` | No | Category for grouping (e.g., "network", "parsing") |
| `feature` | `String?` | No | Feature tag (e.g., "stocks", "payments") |
| `prNumber` | `String?` | No | PR number for tracking changes |

## How It Works

The macros transform your code at compile time to wrap operations with `PerfMeasure.shared.measure()` or `PerfMeasure.shared.measureAsync()` calls.

### Sync Functions → `measure()`
### Async Functions → `measureAsync()`
### Throwing Functions → Preserves `try`

The macro automatically detects:
- Whether the function is `async`
- Whether the function `throws`
- Whether the function returns a value or `Void`

## Testing

Run the macro tests:

```bash
cd /path/to/PerfMeasure
swift test
```

## Notes

- **Recommended import**: Use `import PerfMeasureClient` - it re-exports `PerfMeasure` and provides all macros
- **CocoaPods + SPM**: This package can coexist with your CocoaPods dependencies
- **Body macro auto-detection**: The package automatically enables `@Measured` when building with Swift 5.10+
