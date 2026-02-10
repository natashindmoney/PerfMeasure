# INDProfiler

A lightweight, zero-dependency Swift performance profiling library for iOS & macOS.

Measures **wall-clock time**, **memory**, **CPU**, **thermal state**, and **UI frame rate** — then routes results to pluggable destinations (console, JSONL files, NewRelic, custom analytics).

When profiling is disabled at runtime (via feature flags or configuration), every measurement call reduces to a **single boolean check** before running the closure directly.

## Requirements

- Swift 5.9+
- iOS 17+ / macOS 14+

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/natashindmoney/INDProfiler.git", branch: "main")
```

### CocoaPods (via SPM integration)

```ruby
spm_pkg 'INDProfiler', :git => 'https://github.com/natashindmoney/INDProfiler.git', :branch => 'main'
```

## Runtime Enable / Disable

Profiling is controlled at runtime via `INDProfilerConfiguration.isEnabled`. When disabled, `measure()` / `measureAsync()` skip all metrics collection and run the closure directly — one boolean check of overhead.

```swift
// Disable all profiling
INDProfiler.shared.configure(.disabled)

// Or control via feature flags
INDProfilerDependencies.featureFlagProvider = MyFlagProvider()
INDProfiler.shared.reloadFromFeatureFlags()
```

For release builds, have `isProfilerEnabled()` return `false` in your feature flag provider. The profiler does nothing except forward the closure's return value.

## Quick Start

```swift
import INDProfiler

// Simple — returns the value directly
let users = measured("parseUsers", category: "parsing") {
    try JSONDecoder().decode([User].self, from: data)
}

// Async
let profile = await measuredAsync("fetchProfile", category: "network") {
    try await api.getProfile()
}

// Detailed — access the measurement result
let result = INDProfiler.shared.measure("loadData", feature: "stocks") {
    fetchFromDisk()
}
print(result.measurement?.metrics.formattedDuration ?? "profiling disabled")
```

## API Reference

### Global Helpers

The simplest way to profile a block of code:

```swift
// Sync
let value = measured("name", category: "cat", feature: "feat") { work() }

// Async
let value = await measuredAsync("name") { await asyncWork() }
```

When profiling is disabled, these execute the closure and return its value directly.

### `INDProfiler.shared`

For full control:

```swift
let profiler = INDProfiler.shared

// Closure-based (sync & async)
let result = profiler.measure("op", category: "network") { doWork() }
let result = await profiler.measureAsync("op") { await doAsyncWork() }

// Manual start/stop with checkpoints
let token = profiler.start("flow", category: "onboarding")
token.checkpoint("step_1")
token.checkpoint("step_2")
let result = token.stop()

// UI frame-rate measurement (iOS only)
let uiMeasurement = profiler.measureUIRendering("scrollPerf")
uiMeasurement.start()
// ... user scrolls ...
let result = uiMeasurement.stop()
```

### `MeasuredValue<T>`

Returned by `measure()` and `measureAsync()`:

```swift
struct MeasuredValue<T> {
    let value: T                        // the closure's return value
    let measurement: MeasurementResult? // nil when profiling is disabled
}
```

### Configuration

```swift
// From code
INDProfiler.shared.configure(INDProfilerConfiguration(
    isEnabled: true,
    consoleEnabled: true,
    newRelicEnabled: false,
    jsonlEnabled: true,
    defaultCategory: "general"
))

// From feature flags (set provider first)
INDProfilerDependencies.featureFlagProvider = MyFlagProvider()
INDProfiler.shared.reloadFromFeatureFlags()

// Presets
INDProfiler.shared.configure(.debug)    // all on, zero threshold
INDProfiler.shared.configure(.release)  // console off, NewRelic on
INDProfiler.shared.configure(.disabled) // everything off
```

### Destinations

Results are routed to pluggable destinations:

| Destination | Description |
|-------------|-------------|
| `INDProfilerConsoleDestination` | Logs to `os_log` with coloured duration icons |
| `INDProfilerJSONLDestination` | Appends to a `.jsonl` file with auto-rotation |
| `INDProfilerNewRelicDestination` | Sends to NewRelic via `INDProfilerEventReporting` |
| `INDProfilerAnalyticsDestination` | Forwards to `INDProfilerAnalyticsWriting` |

Add a custom destination:

```swift
class MyDestination: INDProfilerDestination {
    var identifier = "my_dest"
    var isEnabled = true
    func record(_ result: MeasurementResult) { /* ... */ }
}
INDProfiler.shared.addDestination(MyDestination())
```

### Baseline Comparison

```swift
let store = BaselineStore.shared

// Record
store.record(measurementResult)

// Compare
if let comparison = store.compare(newResult) {
    switch comparison.status {
    case .regression:   print("⚠️ \(comparison.durationDeltaPercent)% slower")
    case .improvement:  print("✅ \(comparison.durationDeltaPercent)% faster")
    case .withinExpected: break
    }
}
```

### Dependencies (Host App Integration)

Set these once at app startup:

```swift
INDProfilerDependencies.featureFlagProvider = MyFlagProvider()  // INDProfilerFeatureFlagProviding
INDProfilerDependencies.eventReporter       = MyReporter()      // INDProfilerEventReporting
INDProfilerDependencies.analyticsWriter     = MyWriter()        // INDProfilerAnalyticsWriting
```

### Export

```swift
let exportManager = INDProfilerExportManager.shared

// Get a ZIP archive URL
if let url = exportManager.createShareableArchive() {
    // share via UIActivityViewController, AirDrop, etc.
}
```

## Nested & Chained Measurements

Nested calls work correctly out of the box. Each measurement captures its own independent snapshots:

```swift
let outer = profiler.measure("outer") {
    let a = profiler.measure("inner_a") { doWorkA() }  // dispatched first
    let b = profiler.measure("inner_b") { doWorkB() }  // dispatched second
    return combine(a.value, b.value)
}
// "outer" dispatched last; its duration ≥ inner_a + inner_b
```

Inner results dispatch before outer results (inside-out ordering). Each result has independent duration, memory, and CPU metrics.

## Collected Metrics

Each `MeasurementResult` contains:

| Metric | Description |
|--------|-------------|
| `duration` | Wall-clock time (seconds) |
| `memoryAtStart` / `memoryAtEnd` | Resident memory (bytes) via `mach_task_basic_info` |
| `memoryDelta` | End − Start |
| `cpuUsagePercent` | CPU usage 0–100% normalised by core count |
| `cpuTime` | User + system CPU time consumed (seconds) |
| `thermalState` | Device thermal state at end of measurement |
| `framesRendered` / `droppedFrames` / `frozenFrames` / `averageFPS` | UI rendering metrics (when using `measureUIRendering`) |
| `checkpoints` | Named intermediate timings (manual token API) |

Plus automatic context: source location, build type, app version, device model, OS version, session ID, thread, and optional tags (feature, experiment, PR number, variant, custom).

## License

Internal — INDmoney.
