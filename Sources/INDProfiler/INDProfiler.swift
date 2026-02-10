//
//  INDProfiler.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Main API for performance measurement.
///
/// Profiling is controlled at runtime via `INDProfilerConfiguration.isEnabled`.
/// When disabled, `measure` / `measureAsync` run the closure directly and return
/// `MeasuredValue(value:, measurement: nil)` — a single boolean check per call.
///
/// By default the profiler starts **disabled** (no feature-flag provider is set).
/// Call ``configure(_:)`` or set a ``INDProfilerFeatureFlagProviding`` and call
/// ``reloadFromFeatureFlags()`` to enable it.
public final class INDProfiler {

    /// Shared singleton instance
    public static let shared = INDProfiler()

    /// Current configuration.
    ///
    /// - Note: Accessed on every `measure()` call.  The read is a simple
    ///   struct-field load; there is no lock.  `configure()` should be called
    ///   from a single thread (typically main at startup) to avoid torn reads.
    public private(set) var configuration: INDProfilerConfiguration

    /// Dispatcher for routing to destinations
    private let dispatcher: INDProfilerDispatcher

    /// Metrics collector
    private let metricsCollector: MetricsCollector

    /// Active measurement tokens
    private var activeTokens: [String: MeasurementToken] = [:]
    private let tokensLock = NSLock()

    // MARK: - Initialization

    private init() {
        self.configuration = INDProfilerConfiguration.fromFeatureFlags()
        self.dispatcher = INDProfilerDispatcher()
        self.metricsCollector = MetricsCollector.shared

        setupDefaultDestinations()
    }

    private func setupDefaultDestinations() {
        dispatcher.addDestination(INDProfilerConsoleDestination(
            isEnabled: configuration.consoleEnabled,
            threshold: configuration.consoleThreshold
        ))

        dispatcher.addDestination(INDProfilerNewRelicDestination(
            isEnabled: configuration.newRelicEnabled
        ))

        // JSONL destination defers directory creation to its first write,
        // so adding it here is cheap.
        dispatcher.addDestination(INDProfilerJSONLDestination(
            isEnabled: configuration.jsonlEnabled
        ))

        if INDProfilerDependencies.analyticsWriter != nil {
            dispatcher.addDestination(INDProfilerAnalyticsDestination(
                isEnabled: configuration.analyticsEnabled
            ))
        }
    }

    // MARK: - Configuration

    /// Updates the configuration
    public func configure(_ configuration: INDProfilerConfiguration) {
        self.configuration = configuration

        dispatcher.setDestinationEnabled(INDProfilerConsoleDestination.destinationId, enabled: configuration.consoleEnabled)
        dispatcher.setDestinationEnabled(INDProfilerJSONLDestination.destinationId, enabled: configuration.jsonlEnabled)
        dispatcher.setDestinationEnabled(INDProfilerNewRelicDestination.destinationId, enabled: configuration.newRelicEnabled)
        dispatcher.setDestinationEnabled(INDProfilerAnalyticsDestination.destinationId, enabled: configuration.analyticsEnabled)
    }

    /// Reloads configuration from feature flags
    public func reloadFromFeatureFlags() {
        configure(INDProfilerConfiguration.fromFeatureFlags())
    }

    /// Adds a custom destination
    public func addDestination(_ destination: INDProfilerDestination) {
        dispatcher.addDestination(destination)
    }

    // MARK: - Closure-based Measurement (Sync)

    /// Measures a synchronous operation.
    ///
    /// When `configuration.isEnabled` is `false` the closure runs directly and
    /// `measurement` on the returned value is `nil`.
    @inlinable
    @discardableResult
    public func measure<T>(
        _ name: String,
        category: String? = nil,
        feature: String? = nil,
        experiment: String? = nil,
        prNumber: String? = nil,
        variant: String? = nil,
        customTags: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        operation: () throws -> T
    ) rethrows -> MeasuredValue<T> {
        guard configuration.isEnabled else {
            return MeasuredValue(value: try operation(), measurement: nil)
        }

        return try _measureImpl(
            name,
            category: category,
            feature: feature,
            experiment: experiment,
            prNumber: prNumber,
            variant: variant,
            customTags: customTags,
            file: file,
            function: function,
            line: line,
            operation: operation
        )
    }

    /// Full measurement implementation — only called when profiling is enabled.
    @usableFromInline
    internal func _measureImpl<T>(
        _ name: String,
        category: String?,
        feature: String?,
        experiment: String?,
        prNumber: String?,
        variant: String?,
        customTags: [String: String]?,
        file: String,
        function: String,
        line: Int,
        operation: () throws -> T
    ) rethrows -> MeasuredValue<T> {
        let context = MeasurementContext(
            file: file,
            function: function,
            line: line,
            feature: feature,
            experiment: experiment,
            prNumber: prNumber,
            variant: variant,
            customTags: customTags
        )

        let includeMemory = configuration.includeMemoryMetrics
        let includeCPU = configuration.includeCPUMetrics

        let startSnapshot = metricsCollector.captureSnapshot(
            includeMemory: includeMemory,
            includeCPU: includeCPU
        )
        let startTime = DispatchTime.now()

        let value = try operation()

        let endTime = DispatchTime.now()
        let endSnapshot = metricsCollector.captureSnapshot(
            includeMemory: includeMemory,
            includeCPU: includeCPU
        )

        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        let cpuUsage: Double? = includeCPU
            ? metricsCollector.calculateCPUUsage(start: startSnapshot.cpu, end: endSnapshot.cpu)
            : nil

        let metrics = MeasurementMetrics(
            duration: duration,
            memoryAtStart: startSnapshot.memory.residentSize,
            memoryAtEnd: endSnapshot.memory.residentSize,
            cpuUsagePercent: cpuUsage,
            cpuTime: includeCPU
                ? (endSnapshot.cpu.cpuTime ?? 0) - (startSnapshot.cpu.cpuTime ?? 0)
                : nil,
            thermalState: endSnapshot.thermalState
        )

        let result = MeasurementResult(
            name: name,
            category: category ?? configuration.defaultCategory,
            context: context,
            metrics: metrics
        )

        dispatcher.dispatch(result)

        return MeasuredValue(value: value, measurement: result)
    }

    // MARK: - Closure-based Measurement (Async)

    /// Measures an asynchronous operation.
    ///
    /// When `configuration.isEnabled` is `false` the closure runs directly and
    /// `measurement` on the returned value is `nil`.
    @inlinable
    @discardableResult
    public func measureAsync<T>(
        _ name: String,
        category: String? = nil,
        feature: String? = nil,
        experiment: String? = nil,
        prNumber: String? = nil,
        variant: String? = nil,
        customTags: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        operation: () async throws -> T
    ) async rethrows -> MeasuredValue<T> {
        guard configuration.isEnabled else {
            return MeasuredValue(value: try await operation(), measurement: nil)
        }

        return try await _measureAsyncImpl(
            name,
            category: category,
            feature: feature,
            experiment: experiment,
            prNumber: prNumber,
            variant: variant,
            customTags: customTags,
            file: file,
            function: function,
            line: line,
            operation: operation
        )
    }

    /// Full async measurement implementation — only called when profiling is enabled.
    @usableFromInline
    internal func _measureAsyncImpl<T>(
        _ name: String,
        category: String?,
        feature: String?,
        experiment: String?,
        prNumber: String?,
        variant: String?,
        customTags: [String: String]?,
        file: String,
        function: String,
        line: Int,
        operation: () async throws -> T
    ) async rethrows -> MeasuredValue<T> {
        let context = MeasurementContext(
            file: file,
            function: function,
            line: line,
            feature: feature,
            experiment: experiment,
            prNumber: prNumber,
            variant: variant,
            customTags: customTags
        )

        let includeMemory = configuration.includeMemoryMetrics
        let includeCPU = configuration.includeCPUMetrics

        let startSnapshot = metricsCollector.captureSnapshot(
            includeMemory: includeMemory,
            includeCPU: includeCPU
        )
        let startTime = DispatchTime.now()

        let value = try await operation()

        let endTime = DispatchTime.now()
        let endSnapshot = metricsCollector.captureSnapshot(
            includeMemory: includeMemory,
            includeCPU: includeCPU
        )

        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        let cpuUsage: Double? = includeCPU
            ? metricsCollector.calculateCPUUsage(start: startSnapshot.cpu, end: endSnapshot.cpu)
            : nil

        let metrics = MeasurementMetrics(
            duration: duration,
            memoryAtStart: startSnapshot.memory.residentSize,
            memoryAtEnd: endSnapshot.memory.residentSize,
            cpuUsagePercent: cpuUsage,
            cpuTime: includeCPU
                ? (endSnapshot.cpu.cpuTime ?? 0) - (startSnapshot.cpu.cpuTime ?? 0)
                : nil,
            thermalState: endSnapshot.thermalState
        )

        let result = MeasurementResult(
            name: name,
            category: category ?? configuration.defaultCategory,
            context: context,
            metrics: metrics
        )

        dispatcher.dispatch(result)

        return MeasuredValue(value: value, measurement: result)
    }

    // MARK: - Manual Start/Stop with Checkpoints

    /// Starts a manual measurement and returns a token for tracking.
    ///
    /// When profiling is disabled the returned token is a lightweight stub
    /// whose ``MeasurementToken/stop()`` always returns `nil`.
    public func start(
        _ name: String,
        category: String? = nil,
        feature: String? = nil,
        experiment: String? = nil,
        prNumber: String? = nil,
        variant: String? = nil,
        customTags: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> MeasurementToken {
        let resolvedCategory = category ?? configuration.defaultCategory

        // Fast path — skip context creation, snapshot syscalls, UUID, and
        // dictionary bookkeeping when profiling is off.
        guard configuration.isEnabled else {
            return MeasurementToken(disabledWithName: name, category: resolvedCategory)
        }

        let context = MeasurementContext(
            file: file,
            function: function,
            line: line,
            feature: feature,
            experiment: experiment,
            prNumber: prNumber,
            variant: variant,
            customTags: customTags
        )

        let token = MeasurementToken(
            name: name,
            category: resolvedCategory,
            context: context,
            metricsCollector: metricsCollector,
            dispatcher: dispatcher,
            isEnabled: true,
            includeMemory: configuration.includeMemoryMetrics,
            includeCPU: configuration.includeCPUMetrics
        )

        tokensLock.lock()
        activeTokens[token.id] = token
        tokensLock.unlock()

        return token
    }

    // MARK: - UI Rendering Measurement

#if canImport(UIKit)
    /// Creates a UI rendering measurement session
    public func measureUIRendering(
        _ name: String,
        category: String = "rendering",
        feature: String? = nil,
        experiment: String? = nil,
        prNumber: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> UIRenderingMeasurement {
        let context = MeasurementContext(
            file: file,
            function: function,
            line: line,
            feature: feature,
            experiment: experiment,
            prNumber: prNumber
        )

        return UIRenderingMeasurement(
            name: name,
            category: category,
            context: context,
            metricsCollector: metricsCollector,
            dispatcher: dispatcher,
            isEnabled: configuration.isEnabled
        )
    }
#endif

    // MARK: - Token Cleanup

    internal func removeToken(_ id: String) {
        tokensLock.lock()
        activeTokens.removeValue(forKey: id)
        tokensLock.unlock()
    }
}

// MARK: - Measurement Token

/// Token for manual start/stop measurements with checkpoint support.
///
/// When created via the disabled path, the token is a lightweight stub:
/// no UUID, no mach snapshots, no context.  ``stop()`` returns `nil`
/// immediately.
public final class MeasurementToken {
    public let id: String
    public let name: String
    public let category: String

    private let isEnabled: Bool
    private let context: MeasurementContext?
    private let metricsCollector: MetricsCollector?
    private let dispatcher: INDProfilerDispatcher?
    private let includeMemory: Bool
    private let includeCPU: Bool

    private let startSnapshot: MetricsSnapshot?
    private let startTime: DispatchTime

    private var checkpoints: [MeasurementMetrics.Checkpoint] = []
    private let checkpointsLock = NSLock()
    private var isStopped = false

    // MARK: - Full init (enabled)

    init(
        name: String,
        category: String,
        context: MeasurementContext,
        metricsCollector: MetricsCollector,
        dispatcher: INDProfilerDispatcher,
        isEnabled: Bool,
        includeMemory: Bool = true,
        includeCPU: Bool = true
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.isEnabled = isEnabled
        self.context = context
        self.metricsCollector = metricsCollector
        self.dispatcher = dispatcher
        self.includeMemory = includeMemory
        self.includeCPU = includeCPU
        self.startSnapshot = metricsCollector.captureSnapshot(
            includeMemory: includeMemory,
            includeCPU: includeCPU
        )
        self.startTime = DispatchTime.now()
    }

    // MARK: - Lightweight init (disabled) — no UUID, no syscalls

    init(disabledWithName name: String, category: String) {
        self.id = ""
        self.name = name
        self.category = category
        self.isEnabled = false
        self.context = nil
        self.metricsCollector = nil
        self.dispatcher = nil
        self.includeMemory = false
        self.includeCPU = false
        self.startSnapshot = nil
        self.startTime = .now()
    }

    /// Adds a checkpoint with the current timing
    public func checkpoint(_ name: String) {
        guard isEnabled, !isStopped else { return }

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000

        checkpointsLock.lock()
        checkpoints.append(MeasurementMetrics.Checkpoint(
            name: name,
            elapsedTime: elapsed
        ))
        checkpointsLock.unlock()
    }

    /// Stops the measurement and returns the result
    @discardableResult
    public func stop() -> MeasurementResult? {
        guard isEnabled, !isStopped,
              let context = context,
              let metricsCollector = metricsCollector,
              let dispatcher = dispatcher,
              let startSnapshot = startSnapshot else { return nil }
        isStopped = true

        let endTime = DispatchTime.now()
        let endSnapshot = metricsCollector.captureSnapshot(
            includeMemory: includeMemory,
            includeCPU: includeCPU
        )

        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        let cpuUsage: Double? = includeCPU
            ? metricsCollector.calculateCPUUsage(start: startSnapshot.cpu, end: endSnapshot.cpu)
            : nil

        checkpointsLock.lock()
        let finalCheckpoints = checkpoints
        checkpointsLock.unlock()

        let metrics = MeasurementMetrics(
            duration: duration,
            memoryAtStart: startSnapshot.memory.residentSize,
            memoryAtEnd: endSnapshot.memory.residentSize,
            cpuUsagePercent: cpuUsage,
            cpuTime: includeCPU
                ? (endSnapshot.cpu.cpuTime ?? 0) - (startSnapshot.cpu.cpuTime ?? 0)
                : nil,
            checkpoints: finalCheckpoints,
            thermalState: endSnapshot.thermalState
        )

        let result = MeasurementResult(
            name: name,
            category: category,
            context: context,
            metrics: metrics
        )

        dispatcher.dispatch(result)
        INDProfiler.shared.removeToken(id)

        return result
    }

    /// Current elapsed time since start
    public var elapsedTime: TimeInterval {
        guard isEnabled else { return 0 }
        return Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
    }
}
