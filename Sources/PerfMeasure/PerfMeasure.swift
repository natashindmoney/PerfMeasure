//
//  PerfMeasure.swift
//  INDCommon
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Main API for performance measurement
public final class PerfMeasure: @unchecked Sendable {

    /// Shared singleton instance
    public static let shared = PerfMeasure()

    /// Current configuration
    public private(set) var configuration: PerfMeasureConfiguration

    /// Dispatcher for routing to destinations
    private let dispatcher: PerfMeasureDispatcher

    /// Metrics collector
    private let metricsCollector: MetricsCollector

    /// Active measurement tokens
    private var activeTokens: [String: MeasurementToken] = [:]
    private let tokensLock = NSLock()

    // MARK: - Initialization

    private init() {
        self.configuration = PerfMeasureConfiguration.fromFeatureFlags()
        self.dispatcher = PerfMeasureDispatcher()
        self.metricsCollector = MetricsCollector.shared

        setupDefaultDestinations()
    }

    private func setupDefaultDestinations() {
        dispatcher.addDestination(ConsolePerfDestination(
            isEnabled: configuration.consoleEnabled,
            threshold: configuration.consoleThreshold
        ))

        dispatcher.addDestination(JSONLPerfDestination(
            isEnabled: configuration.jsonlEnabled
        ))

        dispatcher.addDestination(NewRelicPerfDestination(
            isEnabled: configuration.newRelicEnabled
        ))

        if PerfMeasureDependencies.analyticsWriter != nil {
            dispatcher.addDestination(AnalyticsPerfDestination(
                isEnabled: configuration.analyticsEnabled
            ))
        }
    }

    // MARK: - Configuration

    /// Updates the configuration
    public func configure(_ configuration: PerfMeasureConfiguration) {
        self.configuration = configuration

        dispatcher.setDestinationEnabled(ConsolePerfDestination.destinationId, enabled: configuration.consoleEnabled)
        dispatcher.setDestinationEnabled(JSONLPerfDestination.destinationId, enabled: configuration.jsonlEnabled)
        dispatcher.setDestinationEnabled(NewRelicPerfDestination.destinationId, enabled: configuration.newRelicEnabled)
        dispatcher.setDestinationEnabled(AnalyticsPerfDestination.destinationId, enabled: configuration.analyticsEnabled)
    }

    /// Reloads configuration from feature flags
    public func reloadFromFeatureFlags() {
        configure(PerfMeasureConfiguration.fromFeatureFlags())
    }

    /// Adds a custom destination
    public func addDestination(_ destination: PerfMeasureDestination) {
        dispatcher.addDestination(destination)
    }

    // MARK: - Closure-based Measurement (Sync)

    /// Measures a synchronous operation
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

        let startSnapshot = metricsCollector.captureSnapshot()
        let startTime = DispatchTime.now()

        let value = try operation()

        let endTime = DispatchTime.now()
        let endSnapshot = metricsCollector.captureSnapshot()

        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        let cpuUsage = metricsCollector.calculateCPUUsage(start: startSnapshot.cpu, end: endSnapshot.cpu)

        let metrics = MeasurementMetrics(
            duration: duration,
            memoryAtStart: startSnapshot.memory.residentSize,
            memoryAtEnd: endSnapshot.memory.residentSize,
            cpuUsagePercent: cpuUsage,
            cpuTime: (endSnapshot.cpu.cpuTime ?? 0) - (startSnapshot.cpu.cpuTime ?? 0),
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

    /// Measures an asynchronous operation
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
    ) async rethrows -> MeasuredAsyncValue<T> {
        guard configuration.isEnabled else {
            return MeasuredAsyncValue(value: try await operation(), measurement: nil)
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

        let startSnapshot = metricsCollector.captureSnapshot()
        let startTime = DispatchTime.now()

        let value = try await operation()

        let endTime = DispatchTime.now()
        let endSnapshot = metricsCollector.captureSnapshot()

        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        let cpuUsage = metricsCollector.calculateCPUUsage(start: startSnapshot.cpu, end: endSnapshot.cpu)

        let metrics = MeasurementMetrics(
            duration: duration,
            memoryAtStart: startSnapshot.memory.residentSize,
            memoryAtEnd: endSnapshot.memory.residentSize,
            cpuUsagePercent: cpuUsage,
            cpuTime: (endSnapshot.cpu.cpuTime ?? 0) - (startSnapshot.cpu.cpuTime ?? 0),
            thermalState: endSnapshot.thermalState
        )

        let result = MeasurementResult(
            name: name,
            category: category ?? configuration.defaultCategory,
            context: context,
            metrics: metrics
        )

        dispatcher.dispatch(result)

        return MeasuredAsyncValue(value: value, measurement: result)
    }

    // MARK: - Manual Start/Stop with Checkpoints

    /// Starts a manual measurement and returns a token for tracking
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
            category: category ?? configuration.defaultCategory,
            context: context,
            metricsCollector: metricsCollector,
            dispatcher: dispatcher,
            isEnabled: configuration.isEnabled
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

/// Token for manual start/stop measurements with checkpoint support
public final class MeasurementToken: @unchecked Sendable {
    public let id: String
    public let name: String
    public let category: String

    private let context: MeasurementContext
    private let metricsCollector: MetricsCollector
    private let dispatcher: PerfMeasureDispatcher
    private let isEnabled: Bool

    private let startSnapshot: MetricsSnapshot
    private let startTime: DispatchTime

    private var checkpoints: [MeasurementMetrics.Checkpoint] = []
    private let checkpointsLock = NSLock()
    private var isStopped = false

    init(
        name: String,
        category: String,
        context: MeasurementContext,
        metricsCollector: MetricsCollector,
        dispatcher: PerfMeasureDispatcher,
        isEnabled: Bool
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.context = context
        self.metricsCollector = metricsCollector
        self.dispatcher = dispatcher
        self.isEnabled = isEnabled
        self.startSnapshot = metricsCollector.captureSnapshot()
        self.startTime = DispatchTime.now()
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
        guard isEnabled, !isStopped else { return nil }
        isStopped = true

        let endTime = DispatchTime.now()
        let endSnapshot = metricsCollector.captureSnapshot()

        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        let cpuUsage = metricsCollector.calculateCPUUsage(start: startSnapshot.cpu, end: endSnapshot.cpu)

        checkpointsLock.lock()
        let finalCheckpoints = checkpoints
        checkpointsLock.unlock()

        let metrics = MeasurementMetrics(
            duration: duration,
            memoryAtStart: startSnapshot.memory.residentSize,
            memoryAtEnd: endSnapshot.memory.residentSize,
            cpuUsagePercent: cpuUsage,
            cpuTime: (endSnapshot.cpu.cpuTime ?? 0) - (startSnapshot.cpu.cpuTime ?? 0),
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
        PerfMeasure.shared.removeToken(id)

        return result
    }

    /// Current elapsed time since start
    public var elapsedTime: TimeInterval {
        return Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
    }
}
