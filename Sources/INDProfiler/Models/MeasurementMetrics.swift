//
//  MeasurementMetrics.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// All captured metrics for a performance measurement
public struct MeasurementMetrics: Codable, Sendable {

    // MARK: - Time Metrics

    /// Wall-clock duration in seconds
    public let duration: TimeInterval

    // MARK: - Memory Metrics

    /// Memory usage at start in bytes
    public let memoryAtStart: UInt64

    /// Memory usage at end in bytes
    public let memoryAtEnd: UInt64

    /// Memory delta (end - start) in bytes
    public var memoryDelta: Int64 {
        return Int64(memoryAtEnd) - Int64(memoryAtStart)
    }

    // MARK: - CPU Metrics

    /// CPU usage percentage during measurement (0-100)
    public let cpuUsagePercent: Double?

    /// Total CPU time used in seconds
    public let cpuTime: TimeInterval?

    // MARK: - UI Rendering Metrics (optional, for UI measurements)

    /// Number of frames rendered
    public let framesRendered: Int?

    /// Number of dropped frames
    public let droppedFrames: Int?

    /// Number of frozen frames (>700ms)
    public let frozenFrames: Int?

    /// Average frames per second
    public let averageFPS: Double?

    // MARK: - Checkpoints

    /// Intermediate timing checkpoints
    public let checkpoints: [Checkpoint]

    // MARK: - System State

    /// Device thermal state at end of measurement
    public let thermalState: ThermalState

    // MARK: - Types

    public struct Checkpoint: Codable, Sendable {
        public let name: String
        public let elapsedTime: TimeInterval
        public let timestamp: Date

        public init(name: String, elapsedTime: TimeInterval, timestamp: Date = Date()) {
            self.name = name
            self.elapsedTime = elapsedTime
            self.timestamp = timestamp
        }
    }

    public enum ThermalState: String, Codable, Sendable {
        case nominal
        case fair
        case serious
        case critical
        case unknown

        public init(from processInfoState: ProcessInfo.ThermalState) {
            switch processInfoState {
            case .nominal: self = .nominal
            case .fair: self = .fair
            case .serious: self = .serious
            case .critical: self = .critical
            @unknown default: self = .unknown
            }
        }
    }

    // MARK: - Initialization

    public init(
        duration: TimeInterval,
        memoryAtStart: UInt64,
        memoryAtEnd: UInt64,
        cpuUsagePercent: Double? = nil,
        cpuTime: TimeInterval? = nil,
        framesRendered: Int? = nil,
        droppedFrames: Int? = nil,
        frozenFrames: Int? = nil,
        averageFPS: Double? = nil,
        checkpoints: [Checkpoint] = [],
        thermalState: ThermalState = .unknown
    ) {
        self.duration = duration
        self.memoryAtStart = memoryAtStart
        self.memoryAtEnd = memoryAtEnd
        self.cpuUsagePercent = cpuUsagePercent
        self.cpuTime = cpuTime
        self.framesRendered = framesRendered
        self.droppedFrames = droppedFrames
        self.frozenFrames = frozenFrames
        self.averageFPS = averageFPS
        self.checkpoints = checkpoints
        self.thermalState = thermalState
    }

    // MARK: - Dictionary Conversion

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "duration_ms": duration * 1000,
            "memory_at_start_bytes": memoryAtStart,
            "memory_at_end_bytes": memoryAtEnd,
            "memory_delta_bytes": memoryDelta,
            "thermal_state": thermalState.rawValue
        ]

        if let cpuUsagePercent = cpuUsagePercent {
            dict["cpu_usage_percent"] = cpuUsagePercent
        }
        if let cpuTime = cpuTime {
            dict["cpu_time_ms"] = cpuTime * 1000
        }
        if let framesRendered = framesRendered {
            dict["frames_rendered"] = framesRendered
        }
        if let droppedFrames = droppedFrames {
            dict["dropped_frames"] = droppedFrames
        }
        if let frozenFrames = frozenFrames {
            dict["frozen_frames"] = frozenFrames
        }
        if let averageFPS = averageFPS {
            dict["average_fps"] = averageFPS
        }
        if !checkpoints.isEmpty {
            dict["checkpoints"] = checkpoints.map { checkpoint in
                [
                    "name": checkpoint.name,
                    "elapsed_time_ms": checkpoint.elapsedTime * 1000,
                    "timestamp": ISO8601DateFormatter().string(from: checkpoint.timestamp)
                ]
            }
        }

        return dict
    }

    // MARK: - Formatting Helpers

    public var formattedDuration: String {
        if duration < 0.001 {
            return String(format: "%.2f µs", duration * 1_000_000)
        } else if duration < 1 {
            return String(format: "%.2f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }

    public var formattedMemoryDelta: String {
        let bytes = abs(memoryDelta)
        let sign = memoryDelta >= 0 ? "+" : "-"

        if bytes < 1024 {
            return "\(sign)\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%@%.2f KB", sign, Double(bytes) / 1024)
        } else {
            return String(format: "%@%.2f MB", sign, Double(bytes) / (1024 * 1024))
        }
    }
}
