//
//  INDProfilerConsoleDestination.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation
import os.log

/// Destination that logs measurements to the console
public final class INDProfilerConsoleDestination: INDProfilerBaseDestination {

    public static let destinationId = "console"

    /// Minimum duration threshold for logging (in seconds)
    public var threshold: TimeInterval

    private let log = OSLog(subsystem: "com.indmoney.indprofiler", category: "console")

    public init(isEnabled: Bool = true, threshold: TimeInterval = 0.001) {
        self.threshold = threshold
        super.init(identifier: Self.destinationId, isEnabled: isEnabled, qos: .utility)
    }

    override public func performRecord(_ result: MeasurementResult) {
        guard result.metrics.duration >= threshold else { return }

        let output = formatOutput(result)

        #if DEBUG
        os_log(.info, log: log, "%{public}@", output)
        #else
        os_log(.info, log: log, "%@", output)
        #endif
    }

    private func formatOutput(_ result: MeasurementResult) -> String {
        var parts: [String] = []

        // Header with icon based on duration
        let icon = durationIcon(result.metrics.duration)
        parts.append("\(icon) [INDProfiler] \(result.category)/\(result.name)")

        // Duration
        parts.append("  Duration: \(result.metrics.formattedDuration)")

        // Memory
        parts.append("  Memory: \(result.metrics.formattedMemoryDelta)")

        // CPU if available
        if let cpu = result.metrics.cpuUsagePercent {
            parts.append(String(format: "  CPU: %.1f%%", cpu))
        }

        // FPS if available (UI measurements)
        if let fps = result.metrics.averageFPS {
            var fpsLine = String(format: "  FPS: %.1f", fps)
            if let dropped = result.metrics.droppedFrames, dropped > 0 {
                fpsLine += " (dropped: \(dropped))"
            }
            parts.append(fpsLine)
        }

        // Checkpoints
        if !result.metrics.checkpoints.isEmpty {
            parts.append("  Checkpoints:")
            for checkpoint in result.metrics.checkpoints {
                parts.append(String(format: "    • %@: %.2f ms", checkpoint.name, checkpoint.elapsedTime * 1000))
            }
        }

        // Tags
        var tags: [String] = []
        if let feature = result.context.feature {
            tags.append("feature:\(feature)")
        }
        if let pr = result.context.prNumber {
            tags.append("pr:\(pr)")
        }
        if let experiment = result.context.experiment {
            tags.append("exp:\(experiment)")
        }
        if !tags.isEmpty {
            parts.append("  Tags: \(tags.joined(separator: ", "))")
        }

        // Location
        parts.append("  @ \(result.context.file):\(result.context.line)")

        return parts.joined(separator: "\n")
    }

    private func durationIcon(_ duration: TimeInterval) -> String {
        if duration < 0.016 { // <16ms (60fps frame budget)
            return "✅"
        } else if duration < 0.1 { // <100ms
            return "🟡"
        } else if duration < 1.0 { // <1s
            return "🟠"
        } else {
            return "🔴"
        }
    }
}
