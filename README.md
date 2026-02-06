# PerfMeasure

PerfMeasure is the INDmoney performance measurement toolkit packaged as a Swift Package. It ships both the runtime instrumentation APIs and the Swift macros that eliminate boilerplate.

## Overview

### Targets

| Target | Description |
|--------|-------------|
| `PerfMeasure` | Runtime measurement framework (previously in `INDCommon`). |
| `PerfMeasureMacros` | Macro implementation target. |
| `PerfMeasureClient` | Macro client target that exposes the `@Measured` / `#measured` APIs. |

The runtime and macros share the same package so the app only needs to add a single SPM dependency.

### Available Macros

| Macro | Type | Description |
|-------|------|-------------|
| `@Measured` | Attached (body) | Wraps an entire function with performance measurement |
| `#measured` | Freestanding (expression) | Measures a sync expression inline |
| `#measuredAsync` | Freestanding (expression) | Measures an async expression inline |

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
import INDCommon  // For PerfMeasure
import PerfMeasureClient  // For macros
```

### @Measured - Function Wrapper (Swift 5.10+)

Automatically wraps a function with performance measurement. `@Measured` relies on body macros and is currently gated behind the Swift build define `PERFMEASURE_ENABLE_BODY_MACROS`. Enable it once your toolchain supports Swift 5.10 + SwiftSyntax 510 by adding:

```swift
.macro(
    name: "PerfMeasureMacros",
    dependencies: [...],
    swiftSettings: [.define("PERFMEASURE_ENABLE_BODY_MACROS")]
)
```

On Swift 5.9 toolchains, keep the flag disabled (default) and use the `#measured` / `#measuredAsync` expression macros or the `measured(...)` helper functions.

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

## Requirements

- Swift 5.9+
- iOS 14.0+
- Xcode 15.0+
- AutoTracker/EventFileWriter integration (optional): provide a `PerfMeasureAnalyticsWriting` implementation.

## Testing

Run the macro tests:

```bash
cd Packages/PerfMeasureMacros
swift test
```

## Notes

- **Runtime target**: Import `PerfMeasure` for measurement APIs and helper functions
- **Macros target**: Import `PerfMeasureClient` only where macros are used
- **CocoaPods + SPM**: This package can coexist with your CocoaPods dependencies
