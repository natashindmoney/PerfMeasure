//
//  INDProfilerNewRelicDestination.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Destination that sends measurements to NewRelic via EventManager
public final class INDProfilerNewRelicDestination: INDProfilerBaseDestination {

    public static let destinationId = "newrelic"

    /// Event name used for NewRelic reporting
    public static let eventName = "perf_measure"

    /// Minimum duration threshold for reporting (to reduce noise)
    public var reportingThreshold: TimeInterval

    public init(isEnabled: Bool = true, reportingThreshold: TimeInterval = 0.01) {
        self.reportingThreshold = reportingThreshold
        super.init(identifier: Self.destinationId, isEnabled: isEnabled, qos: .utility)
    }

    override public func performRecord(_ result: MeasurementResult) {
        guard
            result.metrics.duration >= reportingThreshold,
            let reporter = INDProfilerDependencies.eventReporter
        else { return }

        let properties = buildProperties(from: result)
        reporter.sendEvent(name: Self.eventName, category: "perf_measure", properties: properties)
    }

    private func buildProperties(from result: MeasurementResult) -> [String: Any] {
        var props: [String: Any] = [
            "name": result.name,
            "category": result.category,
            "duration_ms": result.metrics.duration * 1000,
            "memory_delta_bytes": result.metrics.memoryDelta,
            "build_type": result.context.buildType.rawValue,
            "app_version": result.context.appVersion,
            "device_model": result.context.deviceModel,
            "os_version": result.context.osVersion,
            "thermal_state": result.metrics.thermalState.rawValue,
            "is_main_thread": result.context.isMainThread
        ]

        // Add optional metrics
        if let cpuUsage = result.metrics.cpuUsagePercent {
            props["cpu_usage_percent"] = cpuUsage
        }

        if let fps = result.metrics.averageFPS {
            props["average_fps"] = fps
        }

        if let droppedFrames = result.metrics.droppedFrames {
            props["dropped_frames"] = droppedFrames
        }

        if let frozenFrames = result.metrics.frozenFrames {
            props["frozen_frames"] = frozenFrames
        }

        // Add tags
        if let feature = result.context.feature {
            props["feature"] = feature
        }

        if let experiment = result.context.experiment {
            props["experiment"] = experiment
        }

        if let prNumber = result.context.prNumber {
            props["pr_number"] = prNumber
        }

        if let variant = result.context.variant {
            props["variant"] = variant
        }

        // Add checkpoint count if there are checkpoints
        if !result.metrics.checkpoints.isEmpty {
            props["checkpoint_count"] = result.metrics.checkpoints.count
        }

        return props
    }
}
