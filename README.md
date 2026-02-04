# PerfMeasureMacros

Swift macros for the PerfMeasure performance measurement tool.

## Overview

This package provides Swift macros that make it easy to add performance measurement to your code with minimal boilerplate.

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

## Usage

### Import

```swift
import INDCommon  // For PerfMeasure
import PerfMeasureClient  // For macros
```

### @Measured - Function Wrapper

Automatically wraps a function with performance measurement:

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

## Testing

Run the macro tests:

```bash
cd Packages/PerfMeasureMacros
swift test
```

## Notes

- **Requires INDCommon**: The expanded code uses `PerfMeasure.shared` from the INDCommon framework
- **Import both**: Remember to import both `INDCommon` and `PerfMeasureClient`
- **CocoaPods + SPM**: This package can coexist with your CocoaPods dependencies
