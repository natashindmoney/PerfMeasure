//
//  MetricsCollector.swift
//  INDCommon
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation
import Darwin

/// Collects CPU and memory metrics using mach APIs
public final class MetricsCollector: @unchecked Sendable {

    public static let shared = MetricsCollector()

    private init() {}

    // MARK: - Memory Metrics

    /// Returns current memory usage in bytes
    public func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        return UInt64(info.resident_size)
    }

    /// Returns a snapshot of memory metrics
    public func captureMemorySnapshot() -> MemorySnapshot {
        return MemorySnapshot(
            residentSize: currentMemoryUsage(),
            timestamp: Date()
        )
    }

    // MARK: - CPU Metrics

    /// Returns current CPU time used by the app
    public func currentCPUTime() -> TimeInterval? {
        var threadInfo = task_thread_times_info_data_t()
        var threadCount = mach_msg_type_number_t(MemoryLayout<task_thread_times_info_data_t>.size) / 4

        let kern = withUnsafeMutablePointer(to: &threadInfo) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(threadCount)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), rebound, &threadCount)
            }
        }

        guard kern == KERN_SUCCESS else {
            return nil
        }

        let userTime = Double(threadInfo.user_time.seconds) + Double(threadInfo.user_time.microseconds) / 1_000_000
        let systemTime = Double(threadInfo.system_time.seconds) + Double(threadInfo.system_time.microseconds) / 1_000_000

        return userTime + systemTime
    }

    /// Returns a snapshot of CPU metrics
    public func captureCPUSnapshot() -> CPUSnapshot {
        return CPUSnapshot(
            cpuTime: currentCPUTime(),
            timestamp: Date()
        )
    }

    /// Calculates CPU usage percentage between two snapshots
    public func calculateCPUUsage(start: CPUSnapshot, end: CPUSnapshot) -> Double? {
        guard let startTime = start.cpuTime,
              let endTime = end.cpuTime else {
            return nil
        }

        let cpuTimeDelta = endTime - startTime
        let wallTimeDelta = end.timestamp.timeIntervalSince(start.timestamp)

        guard wallTimeDelta > 0 else {
            return nil
        }

        let cores = Double(ProcessInfo.processInfo.processorCount)
        return min(max((cpuTimeDelta / wallTimeDelta) * 100 / cores, 0), 100)
    }

    // MARK: - Thermal State

    /// Returns current thermal state
    public func currentThermalState() -> MeasurementMetrics.ThermalState {
        return MeasurementMetrics.ThermalState(from: ProcessInfo.processInfo.thermalState)
    }

    // MARK: - Combined Snapshot

    /// Captures a combined snapshot of all metrics
    public func captureSnapshot() -> MetricsSnapshot {
        return MetricsSnapshot(
            memory: captureMemorySnapshot(),
            cpu: captureCPUSnapshot(),
            thermalState: currentThermalState()
        )
    }
}

// MARK: - Snapshot Types

public struct MemorySnapshot: Sendable {
    public let residentSize: UInt64
    public let timestamp: Date

    public init(residentSize: UInt64, timestamp: Date) {
        self.residentSize = residentSize
        self.timestamp = timestamp
    }
}

public struct CPUSnapshot: Sendable {
    public let cpuTime: TimeInterval?
    public let timestamp: Date

    public init(cpuTime: TimeInterval?, timestamp: Date) {
        self.cpuTime = cpuTime
        self.timestamp = timestamp
    }
}

public struct MetricsSnapshot: Sendable {
    public let memory: MemorySnapshot
    public let cpu: CPUSnapshot
    public let thermalState: MeasurementMetrics.ThermalState

    public init(memory: MemorySnapshot, cpu: CPUSnapshot, thermalState: MeasurementMetrics.ThermalState) {
        self.memory = memory
        self.cpu = cpu
        self.thermalState = thermalState
    }
}
