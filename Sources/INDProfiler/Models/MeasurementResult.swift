//
//  MeasurementResult.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Complete measurement record containing name, category, context, and metrics
public struct MeasurementResult: Codable, Sendable {

    /// Unique identifier for this measurement
    public let id: String

    /// Name of the operation being measured
    public let name: String

    /// Category for grouping measurements (e.g., "network", "parsing", "rendering")
    public let category: String

    /// Context information (automatic and manual tags)
    public let context: MeasurementContext

    /// Captured metrics
    public let metrics: MeasurementMetrics

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String,
        category: String,
        context: MeasurementContext,
        metrics: MeasurementMetrics
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.context = context
        self.metrics = metrics
    }

    // MARK: - Dictionary Conversion

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "category": category
        ]

        // Merge context and metrics dictionaries
        for (key, value) in context.toDictionary() {
            dict["ctx_\(key)"] = value
        }

        for (key, value) in metrics.toDictionary() {
            dict[key] = value
        }

        return dict
    }

    // MARK: - Console Description

    public var consoleDescription: String {
        var lines: [String] = []

        lines.append("[\(category)] \(name)")
        lines.append("  Duration: \(metrics.formattedDuration)")
        lines.append("  Memory: \(metrics.formattedMemoryDelta)")

        if let cpuUsage = metrics.cpuUsagePercent {
            lines.append(String(format: "  CPU: %.1f%%", cpuUsage))
        }

        if let fps = metrics.averageFPS {
            lines.append(String(format: "  FPS: %.1f", fps))
            if let dropped = metrics.droppedFrames {
                lines.append("  Dropped: \(dropped) frames")
            }
        }

        if !metrics.checkpoints.isEmpty {
            lines.append("  Checkpoints:")
            for checkpoint in metrics.checkpoints {
                lines.append(String(format: "    - %@: %.2f ms", checkpoint.name, checkpoint.elapsedTime * 1000))
            }
        }

        if let feature = context.feature {
            lines.append("  Feature: \(feature)")
        }

        if let prNumber = context.prNumber {
            lines.append("  PR: \(prNumber)")
        }

        return lines.joined(separator: "\n")
    }
}

/// Wrapper for a measurement result paired with the operation's return value.
///
/// Used by both sync and async measurement APIs.
public struct MeasuredValue<T> {
    /// The value returned by the measured operation
    public let value: T

    /// The measurement result (nil if measurement is disabled)
    public let measurement: MeasurementResult?

    @inlinable
    public init(value: T, measurement: MeasurementResult?) {
        self.value = value
        self.measurement = measurement
    }
}
