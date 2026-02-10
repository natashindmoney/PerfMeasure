import XCTest
@testable import INDProfiler

final class MetricsCollectorTests: XCTestCase {

    let collector = MetricsCollector.shared

    // MARK: - Memory Metrics

    func testCurrentMemoryUsageReturnsNonZero() {
        let usage = collector.currentMemoryUsage()
        XCTAssertGreaterThan(usage, 0, "Memory usage should be non-zero for a running process")
    }

    func testCaptureMemorySnapshot() {
        let snapshot = collector.captureMemorySnapshot()
        XCTAssertGreaterThan(snapshot.residentSize, 0)
        XCTAssertLessThanOrEqual(snapshot.timestamp.timeIntervalSinceNow, 0)
    }

    // MARK: - CPU Metrics

    func testCurrentCPUTimeReturnsValue() {
        let cpuTime = collector.currentCPUTime()
        XCTAssertNotNil(cpuTime, "CPU time should be available")
        if let cpuTime = cpuTime {
            XCTAssertGreaterThan(cpuTime, 0, "CPU time should be positive")
        }
    }

    func testCaptureCPUSnapshot() {
        let snapshot = collector.captureCPUSnapshot()
        XCTAssertNotNil(snapshot.cpuTime)
        XCTAssertLessThanOrEqual(snapshot.timestamp.timeIntervalSinceNow, 0)
    }

    func testCalculateCPUUsageBetweenSnapshots() {
        let start = collector.captureCPUSnapshot()

        // Do some work to use CPU
        var sum = 0.0
        for i in 0..<100_000 { sum += Double(i) * Double(i) }
        _ = sum

        let end = collector.captureCPUSnapshot()
        let usage = collector.calculateCPUUsage(start: start, end: end)

        XCTAssertNotNil(usage)
        if let usage = usage {
            XCTAssertGreaterThanOrEqual(usage, 0)
            XCTAssertLessThanOrEqual(usage, 100)
        }
    }

    func testCalculateCPUUsageWithNilTimesReturnsNil() {
        let start = CPUSnapshot(cpuTime: nil, timestamp: Date())
        let end = CPUSnapshot(cpuTime: nil, timestamp: Date())
        let usage = collector.calculateCPUUsage(start: start, end: end)
        XCTAssertNil(usage)
    }

    func testCalculateCPUUsageWithZeroWallTimeReturnsNil() {
        let now = Date()
        let start = CPUSnapshot(cpuTime: 1.0, timestamp: now)
        let end = CPUSnapshot(cpuTime: 2.0, timestamp: now)
        let usage = collector.calculateCPUUsage(start: start, end: end)
        XCTAssertNil(usage)
    }

    // MARK: - Thermal State

    func testCurrentThermalState() {
        let state = collector.currentThermalState()
        // Should return a valid value
        let validStates: [MeasurementMetrics.ThermalState] = [.nominal, .fair, .serious, .critical, .unknown]
        XCTAssertTrue(validStates.contains(state))
    }

    // MARK: - Combined Snapshot

    func testCaptureSnapshot() {
        let snapshot = collector.captureSnapshot()
        XCTAssertGreaterThan(snapshot.memory.residentSize, 0)
        XCTAssertNotNil(snapshot.cpu.cpuTime)
    }
}
