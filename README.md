# INDProfiler

A lightweight, zero-dependency Swift performance profiling library for iOS & macOS.

Measures **wall-clock time**, **memory**, **CPU**, **thermal state**, and **UI frame rate** — then routes results to pluggable destinations (console, JSONL files, NewRelic, custom analytics).

**Designed to be risk-free for clients.** When profiling is disabled (the default), each measurement call reduces to a single boolean check — no allocations, no syscalls, no side effects.

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

## Performance Characteristics

### When profiling is disabled (default)

The profiler starts **disabled** until explicitly configured. The overhead of a disabled `measured()` call is:

| Step | Cost |
|------|------|
| `INDProfiler.shared` singleton access | ~1 ns (static let) |
| `configuration.isEnabled` read | ~1 ns (struct field) |
| Branch, run closure, return | 0 ns |
| **Total** | **~2-5 ns** |

No `MeasurementContext` is created. No UUID is generated. No mach syscalls. No lock is taken. No memory is allocated. The `@inlinable` annotation on `measured()` and `measure()` allows the compiler to inline the disabled-path guard check directly at the call site when compiling with optimizations.

For the token API (`start()` / `stop()`), the disabled path returns a lightweight stub — no UUID, no context, no mach snapshots, no dictionary bookkeeping.

### When profiling is enabled

Each `measure()` call adds:

| Step | Cost |
|------|------|
| `MeasurementContext` creation | ~0.1 µs (all device/app info cached as `static let`) |
| `captureSnapshot()` × 2 (start + end) | ~2-4 µs (mach `task_info` syscalls) |
| `DispatchTime.now()` × 2 | ~0.02 µs |
| `MeasurementResult` + UUID | ~0.1 µs |
| `dispatch()` to destinations | ~0.2 µs (NSLock + array iterate) |
| Each destination's `record()` | Background queue — off the caller's thread |
| **Total on caller's thread** | **~3-5 µs** |

You can reduce this further by disabling metrics you don't need:

```swift
INDProfiler.shared.configure(INDProfilerConfiguration(
    isEnabled: true,
    includeMemoryMetrics: false,  // skip 2 mach_task_basic_info syscalls
    includeCPUMetrics: false      // skip 2 task_thread_times_info syscalls
))
```

With both disabled, overhead drops to **~0.5 µs** (wall-clock timing only).

### Startup cost

| | When disabled (default) | When enabled |
|--|-------------------------|--------------|
| Singleton init | 4 destination objects + GCD queues (~10 µs) | Same |
| Filesystem I/O | None (JSONL directory deferred to first write) | Directory created on first log |

The singleton is initialized lazily on first access. It starts disabled (no feature flag provider → `isEnabled = false`), so no profiling work occurs until `configure()` is called.

## Runtime Enable / Disable

Profiling is controlled at runtime via `INDProfilerConfiguration.isEnabled`. When disabled, `measure()` / `measureAsync()` skip all metrics collection and run the closure directly — one boolean check of overhead.

```swift
// Enable with explicit config
INDProfiler.shared.configure(.debug)

// Or control via feature flags
INDProfilerDependencies.featureFlagProvider = MyFlagProvider()
INDProfiler.shared.reloadFromFeatureFlags()

// Disable all profiling
INDProfiler.shared.configure(.disabled)
```

For release builds, have `isProfilerEnabled()` return `false` in your feature flag provider. The profiler does nothing except forward the closure's return value.

## Quick Start

```swift
import INDProfiler

// Enable profiling first (disabled by default)
INDProfiler.shared.configure(.debug)

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
    includeMemoryMetrics: true,
    includeCPUMetrics: true,
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

All destination recording happens on background dispatch queues — never on the caller's thread.

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
