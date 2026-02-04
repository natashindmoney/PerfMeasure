# PerfMeasure - Technical Specification

**Version:** 1.0
**Date:** February 2026
**Author:** Performance Engineering Team
**Status:** Implementation Complete

---

## 1. Executive Summary

PerfMeasure is a comprehensive performance measurement framework for the INDmoney iOS app. It provides developers with easy-to-use APIs to capture time, memory, CPU, and frame rate metrics with automatic contextual tagging, baseline comparison, and flexible export options.

### Key Features

- **Multiple measurement APIs**: Closure-based, manual start/stop, checkpoints, UI rendering
- **Comprehensive metrics**: Duration, memory delta, CPU usage, frame rate, thermal state
- **Automatic tagging**: File, function, line, build type, device model, OS version
- **Manual tagging**: Feature, experiment, PR number, variant, custom tags
- **Baseline comparison**: Store baselines, compare measurements, detect regressions
- **Flexible destinations**: Console, NewRelic, JSONL file export
- **Swift macros**: `@Measured`, `#measured`, `#measuredAsync` (separate SPM package)
- **Runtime control**: Feature flag integration for dynamic enable/disable

---

## 2. Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          User Code                                   │
│  @Measured | #measured | measure{} | start/stop | measureUIRendering│
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          PerfMeasure                                 │
│                    (Singleton - Main API)                            │
│  • Configuration management                                          │
│  • Measurement orchestration                                         │
│  • Token management for manual measurements                          │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
        ┌───────────────┐ ┌─────────────┐ ┌──────────────┐
        │MetricsCollector│ │MeasurementContext│ │UIRendering │
        │ • Memory (mach)│ │ • Auto tags │ │Measurement   │
        │ • CPU (task)   │ │ • Manual tags│ │• CADisplayLink│
        │ • Thermal      │ │ • Device info│ │• Frame tracking│
        └───────────────┘ └─────────────┘ └──────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     PerfMeasureDispatcher                            │
│              (Routes MeasurementResult to destinations)              │
└─────────────────────────────────────────────────────────────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
    ┌──────────────────┐ ┌─────────────────┐ ┌─────────────────┐
    │ConsolePerfDest   │ │JSONLPerfDest    │ │NewRelicPerfDest │
    │• Debug logging   │ │• File storage   │ │• EventManager   │
    │• Threshold filter│ │• File rotation  │ │• Tech events    │
    └──────────────────┘ └─────────────────┘ └─────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        BaselineStore                                 │
│  • Store running averages per operation                              │
│  • Compare measurements against baselines                            │
│  • Import/export baselines for team sharing                          │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Package Structure

```
INDCommon/Source/PerformanceMeasurement/
├── PerfMeasure.swift                    # Main API singleton
├── PerfMeasureConfiguration.swift       # Configuration management
├── PerfMeasureDispatcher.swift          # Destination routing
├── Measured.swift                       # Global helper functions
│
├── Models/
│   ├── MeasurementContext.swift         # Auto + manual tags
│   ├── MeasurementMetrics.swift         # Captured metrics
│   └── MeasurementResult.swift          # Complete record
│
├── Collection/
│   ├── MetricsCollector.swift           # CPU, memory (mach APIs)
│   └── UIRenderingMeasurement.swift     # Frame rate (CADisplayLink)
│
├── Destinations/
│   ├── PerfMeasureDestination.swift     # Protocol + base class
│   ├── ConsolePerfDestination.swift     # Debug console
│   ├── JSONLPerfDestination.swift       # File storage
│   └── NewRelicPerfDestination.swift    # NewRelic reporting
│
├── Baseline/
│   └── BaselineStore.swift              # Baseline storage/comparison
│
└── Export/
    └── PerfMeasureExportManager.swift   # Export bundle creation

Packages/PerfMeasureMacros/              # Separate SPM package
├── Package.swift
├── Sources/
│   ├── PerfMeasureMacros/               # Macro implementations
│   │   ├── PerfMeasureMacrosPlugin.swift
│   │   ├── MeasuredMacro.swift
│   │   └── MeasuredExpressionMacro.swift
│   └── PerfMeasureClient/               # Public declarations
│       └── PerfMeasureClient.swift
└── Tests/
    └── PerfMeasureMacrosTests/
```

---

## 3. Data Models

### 3.1 MeasurementContext

Captures contextual information about where and when a measurement occurred.

```swift
public struct MeasurementContext: Codable, Sendable {
    // Automatic - Source Location
    let file: String           // "StocksViewController.swift"
    let function: String       // "loadStocks()"
    let line: Int              // 42

    // Automatic - Build Info
    let buildType: BuildType   // .debug | .testflight | .appstore
    let appVersion: String     // "6.1.9"
    let buildNumber: String    // "1234"

    // Automatic - Device Info
    let deviceModel: String    // "iPhone14,3"
    let osVersion: String      // "17.0"

    // Automatic - Runtime
    let sessionId: String      // UUID for app session
    let timestamp: Date
    let isMainThread: Bool

    // Manual Tags
    let feature: String?       // "stocks", "payments"
    let experiment: String?    // "new_trade_flow"
    let prNumber: String?      // "PR-123"
    let variant: String?       // "A", "B"
    let customTags: [String: String]?
}
```

### 3.2 MeasurementMetrics

All captured performance metrics for a measurement.

```swift
public struct MeasurementMetrics: Codable, Sendable {
    // Time
    let duration: TimeInterval          // Wall-clock seconds

    // Memory
    let memoryAtStart: UInt64           // Bytes
    let memoryAtEnd: UInt64             // Bytes
    var memoryDelta: Int64 { get }      // Computed

    // CPU
    let cpuUsagePercent: Double?        // 0-100
    let cpuTime: TimeInterval?          // Seconds

    // UI Rendering (optional)
    let framesRendered: Int?
    let droppedFrames: Int?
    let frozenFrames: Int?              // >700ms frames
    let averageFPS: Double?

    // Checkpoints
    let checkpoints: [Checkpoint]

    // System State
    let thermalState: ThermalState      // nominal|fair|serious|critical
}
```

### 3.3 MeasurementResult

Complete measurement record combining name, category, context, and metrics.

```swift
public struct MeasurementResult: Codable, Sendable {
    let id: String              // UUID
    let name: String            // "loadStocks"
    let category: String        // "network"
    let context: MeasurementContext
    let metrics: MeasurementMetrics

    func toDictionary() -> [String: Any]
    var consoleDescription: String { get }
}
```

### 3.4 Baseline

Stored baseline data for comparison.

```swift
public struct Baseline: Codable {
    let name: String
    let category: String
    var sampleCount: Int
    var totalDuration: TimeInterval
    var minDuration: TimeInterval
    var maxDuration: TimeInterval
    var lastUpdated: Date
    var totalMemoryDelta: Int64
    var appVersion: String

    var averageDuration: TimeInterval { get }
    var averageMemoryDelta: Int64 { get }
}
```

---

## 4. API Reference

### 4.1 Closure-based Measurement

**Synchronous:**
```swift
let result = PerfMeasure.shared.measure(
    "operationName",
    category: "network",
    feature: "stocks",
    prNumber: "PR-123"
) {
    return performOperation()
}
// result.value = return value
// result.measurement = MeasurementResult?
```

**Asynchronous:**
```swift
let result = await PerfMeasure.shared.measureAsync(
    "asyncOperation",
    category: "network"
) {
    try await fetchData()
}
```

### 4.2 Global Helper Functions

```swift
// Simple - returns value directly
let data = measured("parseJSON", category: "parsing") {
    try JSONDecoder().decode(Model.self, from: json)
}

// With result access
let result = measuredWithResult("operation") { performWork() }
print("Took: \(result.measurement?.metrics.formattedDuration)")

// Async variants
let profile = await measuredAsync("loadProfile") { await load() }
let result = await measuredAsyncWithResult("fetch") { await fetch() }
```

### 4.3 Manual Start/Stop with Checkpoints

```swift
let token = PerfMeasure.shared.start(
    "complexOperation",
    category: "processing",
    feature: "data"
)

// Phase 1
loadData()
token.checkpoint("dataLoaded")

// Phase 2
processData()
token.checkpoint("dataProcessed")

// Phase 3
saveData()
let result = token.stop()

// Access checkpoint timings
result?.metrics.checkpoints.forEach { checkpoint in
    print("\(checkpoint.name): \(checkpoint.elapsedTime * 1000)ms")
}
```

### 4.4 UI Rendering Measurement

```swift
let rendering = PerfMeasure.shared.measureUIRendering(
    "scrollPerformance",
    category: "rendering",
    feature: "feed"
)

rendering.start()
// ... perform UI operations, scrolling, animations ...
let result = rendering.stop()

print("Average FPS: \(result?.metrics.averageFPS ?? 0)")
print("Dropped frames: \(result?.metrics.droppedFrames ?? 0)")
print("Frozen frames: \(result?.metrics.frozenFrames ?? 0)")
```

### 4.5 Swift Macros (SPM Package)

**@Measured - Function wrapper:**
```swift
@Measured("fetchStocks", category: "network", feature: "stocks")
func fetchStocks() async throws -> [Stock] {
    return try await api.getStocks()
}
```

**#measured - Inline expression:**
```swift
let user = #measured("parseUser", category: "parsing") {
    try JSONDecoder().decode(User.self, from: data)
}
```

**#measuredAsync - Async inline:**
```swift
let profile = await #measuredAsync("fetchProfile") {
    try await api.getProfile()
}
```

### 4.6 Baseline Comparison

```swift
// Record measurement for baseline tracking
let result = PerfMeasure.shared.measure("criticalPath") { ... }
if let measurement = result.measurement {
    BaselineStore.shared.record(measurement)
}

// Compare against baseline
if let comparison = BaselineStore.shared.compare(measurement) {
    switch comparison.status {
    case .regression:
        print("⚠️ \(comparison.durationDeltaPercent)% slower than baseline")
    case .improvement:
        print("✅ \(abs(comparison.durationDeltaPercent))% faster")
    case .withinExpected:
        print("📊 Within expected range (±20%)")
    }
}

// Export baselines for team sharing
if let data = BaselineStore.shared.exportData() {
    // Share with team
}

// Import baselines
try BaselineStore.shared.importData(sharedData)
```

---

## 5. Configuration

### 5.1 Feature Flags

```swift
extension INDFeatureFlag {
    enum PerfMeasure {
        @INDFeatureFlag("Enable PerfMeasure", key: "perf_measure.enabled", fallback: false)
        public static var enabled

        @INDFeatureFlag("Console Logging", key: "perf_measure.console_enabled", fallback: true)
        public static var consoleEnabled

        @INDFeatureFlag("NewRelic Reporting", key: "perf_measure.newrelic_enabled", fallback: true)
        public static var newRelicEnabled

        @INDFeatureFlag("JSONL Export", key: "perf_measure.jsonl_enabled", fallback: true)
        public static var jsonlEnabled
    }
}
```

### 5.2 Configuration Options

```swift
public struct PerfMeasureConfiguration {
    var isEnabled: Bool                    // Master switch
    var consoleEnabled: Bool               // Console destination
    var newRelicEnabled: Bool              // NewRelic destination
    var jsonlEnabled: Bool                 // JSONL file destination
    var consoleThreshold: TimeInterval     // Min duration for console (default: 1ms)
    var includeMemoryMetrics: Bool         // Capture memory
    var includeCPUMetrics: Bool            // Capture CPU
    var defaultCategory: String            // Default category name

    // Presets
    static var debug: PerfMeasureConfiguration
    static var release: PerfMeasureConfiguration
    static var disabled: PerfMeasureConfiguration

    // Feature flag integration
    static func fromFeatureFlags() -> PerfMeasureConfiguration
}
```

### 5.3 Runtime Configuration

```swift
// Update configuration
PerfMeasure.shared.configure(PerfMeasureConfiguration(
    isEnabled: true,
    consoleEnabled: true,
    newRelicEnabled: false,
    jsonlEnabled: true,
    consoleThreshold: 0.01  // 10ms minimum for console
))

// Reload from feature flags
PerfMeasure.shared.reloadFromFeatureFlags()

// Add custom destination
PerfMeasure.shared.addDestination(MyCustomDestination())
```

---

## 6. Destinations

### 6.1 Console Destination

- **Purpose:** Debug logging during development
- **Output:** os_log with formatted output
- **Features:**
  - Duration threshold filter (skip fast operations)
  - Color-coded icons based on duration
  - Checkpoint timing display
  - Tag display

**Sample Output:**
```
✅ [PerfMeasure] network/loadStocks
  Duration: 45.23 ms
  Memory: +1.24 MB
  CPU: 12.3%
  Checkpoints:
    • apiCall: 30.12 ms
    • parsing: 42.56 ms
  Tags: feature:stocks, pr:PR-123
  @ StocksViewController.swift:42
```

### 6.2 JSONL Destination

- **Purpose:** Local file storage for export/analysis
- **Location:** `Documents/PerfMeasure/measurements.jsonl`
- **Features:**
  - One JSON object per line
  - Automatic file rotation (10MB default)
  - Archive retention (5 files default)
  - Clear all method

**Sample Line:**
```json
{"id":"abc-123","name":"loadStocks","category":"network","duration_ms":45.23,"memory_delta_bytes":1302528,"ctx_feature":"stocks","ctx_pr_number":"PR-123"}
```

### 6.3 NewRelic Destination

- **Purpose:** Production monitoring and alerting
- **Integration:** Uses existing `EventManager.shared.sendTechEvent()`
- **Event Name:** `perf_measure`
- **Features:**
  - Minimum reporting threshold (10ms default)
  - All context and metrics as event properties

---

## 7. Metrics Collection

### 7.1 Memory (mach API)

```swift
// Uses mach_task_basic_info
var info = mach_task_basic_info()
task_info(mach_task_self_, MACH_TASK_BASIC_INFO, &info, &count)
return info.resident_size  // Bytes
```

### 7.2 CPU (task_info API)

```swift
// Uses task_thread_times_info
var threadInfo = task_thread_times_info_data_t()
task_info(mach_task_self_, TASK_THREAD_TIMES_INFO, &threadInfo, &count)

let userTime = threadInfo.user_time.seconds + threadInfo.user_time.microseconds / 1_000_000
let systemTime = threadInfo.system_time.seconds + threadInfo.system_time.microseconds / 1_000_000
return userTime + systemTime
```

### 7.3 Frame Rate (CADisplayLink)

```swift
// Uses CADisplayLink for frame timing
displayLink = CADisplayLink(target: self, selector: #selector(handleFrame))
displayLink.add(to: .main, forMode: .common)

// Track:
// - frameCount: Total frames rendered
// - droppedFrames: Frames > 33ms (2x target)
// - frozenFrames: Frames > 700ms
// - averageFPS: frameCount / duration
```

### 7.4 Thermal State

```swift
ProcessInfo.processInfo.thermalState
// .nominal | .fair | .serious | .critical
```

---

## 8. Storage Locations

| Data | Location | Format |
|------|----------|--------|
| Measurements | `Documents/PerfMeasure/measurements.jsonl` | JSONL |
| Archives | `Documents/PerfMeasure/measurements_*.jsonl` | JSONL |
| Baselines | `Documents/PerfBaselines/baselines.json` | JSON |
| Exports | `tmp/PerfMeasureExport_*/` | Directory |

---

## 9. Thread Safety

| Component | Strategy |
|-----------|----------|
| PerfMeasure | Main singleton, token management via NSLock |
| MetricsCollector | Stateless, thread-safe mach API calls |
| PerfMeasureDispatcher | Concurrent queue with barrier for writes |
| BaselineStore | Serial dispatch queue |
| All Destinations | Serial dispatch queues (via BasePerfMeasureDestination) |
| MeasurementToken | NSLock for checkpoint array |
| UIRenderingMeasurement | NSLock for frame counters |

---

## 10. Performance Overhead

### Design Principles

1. **Lazy initialization:** Destinations created on first use
2. **Async dispatch:** All destination recording is async
3. **Configurable thresholds:** Filter out noise at source
4. **Feature flags:** Complete disable path with minimal overhead
5. **Efficient snapshots:** Mach APIs are fast (~microseconds)

### Estimated Overhead

| Operation | Overhead |
|-----------|----------|
| Disabled check | ~1 nanosecond |
| Memory snapshot | ~5 microseconds |
| CPU snapshot | ~10 microseconds |
| Full measurement | ~50-100 microseconds |
| Console logging | Async, no blocking |
| JSONL write | Async, buffered |
| NewRelic send | Async via EventManager |

---

## 11. Integration Guide

### 11.1 Basic Integration

```swift
import INDCommon

// Measure a network call
func loadUserProfile() async throws -> Profile {
    return try await PerfMeasure.shared.measureAsync(
        "loadUserProfile",
        category: "network",
        feature: "profile"
    ) {
        try await api.fetchProfile()
    }.value
}
```

### 11.2 With Macros (requires SPM)

```swift
import INDCommon
import PerfMeasureClient

@Measured("loadUserProfile", category: "network", feature: "profile")
func loadUserProfile() async throws -> Profile {
    return try await api.fetchProfile()
}
```

### 11.3 Screen Load Measurement

```swift
class StocksViewController: UIViewController {
    private var loadToken: MeasurementToken?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadToken = PerfMeasure.shared.start(
            "stocksScreenLoad",
            category: "screen",
            feature: "stocks"
        )

        loadToken?.checkpoint("viewDidLoad")
        loadData()
    }

    private func loadData() {
        api.fetchStocks { [weak self] stocks in
            self?.loadToken?.checkpoint("dataLoaded")
            self?.renderStocks(stocks)
        }
    }

    private func renderStocks(_ stocks: [Stock]) {
        tableView.reloadData()
        loadToken?.checkpoint("rendered")

        DispatchQueue.main.async {
            let result = self.loadToken?.stop()
            // Screen fully loaded, measurement complete
        }
    }
}
```

### 11.4 A/B Testing Integration

```swift
let variant = ABTestManager.shared.variant(for: "new_trade_flow")

let result = PerfMeasure.shared.measure(
    "executeTrade",
    category: "trading",
    feature: "trade",
    experiment: "new_trade_flow",
    variant: variant
) {
    return executeTrade(order)
}

// NewRelic will receive experiment and variant tags for analysis
```

---

## 12. Export & Analysis

### 12.1 Export Data

```swift
// Create shareable archive
if let archiveURL = PerfMeasureExportManager.shared.createShareableArchive() {
    // Share via AirDrop, email, etc.
}

// Present share sheet
PerfMeasureExportManager.shared.presentShareSheet(from: viewController)
```

### 12.2 Export Contents

```
PerfMeasure_20260204_143022.zip
├── measurements.jsonl    # All measurements
├── baselines.json        # Stored baselines
└── metadata.json         # Export info (app version, device, date)
```

### 12.3 Analysis Scripts

JSONL files can be analyzed with standard tools:

```bash
# Count measurements by category
cat measurements.jsonl | jq -s 'group_by(.category) | map({category: .[0].category, count: length})'

# Find slowest operations
cat measurements.jsonl | jq -s 'sort_by(.duration_ms) | reverse | .[0:10]'

# Filter by feature
cat measurements.jsonl | jq 'select(.ctx_feature == "stocks")'
```

---

## 13. Testing

### 13.1 Unit Tests

```swift
func testMeasureReturnsCorrectValue() {
    let result = PerfMeasure.shared.measure("test") {
        return 42
    }
    XCTAssertEqual(result.value, 42)
    XCTAssertNotNil(result.measurement)
}

func testCheckpointsRecorded() {
    let token = PerfMeasure.shared.start("test")
    token.checkpoint("step1")
    token.checkpoint("step2")
    let result = token.stop()

    XCTAssertEqual(result?.metrics.checkpoints.count, 2)
    XCTAssertEqual(result?.metrics.checkpoints[0].name, "step1")
}

func testBaselineComparison() {
    let measurement = createTestMeasurement(duration: 0.1)
    BaselineStore.shared.record(measurement)

    let slowerMeasurement = createTestMeasurement(duration: 0.15)
    let comparison = BaselineStore.shared.compare(slowerMeasurement)

    XCTAssertEqual(comparison?.status, .regression)
}
```

### 13.2 Integration Tests

```swift
func testRealNetworkMeasurement() async throws {
    let result = await PerfMeasure.shared.measureAsync("realRequest") {
        try await URLSession.shared.data(from: testURL)
    }

    XCTAssertNotNil(result.measurement)
    XCTAssertGreaterThan(result.measurement!.metrics.duration, 0)
    XCTAssertGreaterThan(result.measurement!.metrics.memoryAtEnd, 0)
}
```

---

## 14. Future Enhancements

1. **Instruments Integration:** Bridge to os_signpost for Instruments profiling
2. **Sampling Mode:** Automatic sampling for high-frequency operations
3. **Aggregation:** Automatic aggregation of repeated measurements
4. **Alerting:** In-app alerts for regressions during development
5. **Dashboard:** SwiftUI debug dashboard for real-time monitoring
6. **Network Metrics:** Integration with URLSession metrics
7. **Core Data Metrics:** Automatic Core Data operation tracking

---

## 15. Dependencies

### INDCommon (CocoaPods)

- No additional dependencies required
- Uses system frameworks: Foundation, UIKit, Darwin, QuartzCore, os.log

### PerfMeasureMacros (SPM)

- swift-syntax 509.0.0+
- SwiftSyntaxMacros
- SwiftCompilerPlugin

---

## 16. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 2026 | Initial implementation |
