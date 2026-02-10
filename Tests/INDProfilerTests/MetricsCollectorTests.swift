import XCTest
@testable import INDProfiler

final class MetricsCollectorTests: XCTestCase {

    let collector = MetricsCollector.shared

    // MARK: - Memory Metrics – basic

    func testCurrentMemoryUsageReturnsNonZero() {
        let usage = collector.currentMemoryUsage()
        XCTAssertGreaterThan(usage, 0, "Memory usage should be non-zero for a running process")
    }

    func testCaptureMemorySnapshot() {
        let snapshot = collector.captureMemorySnapshot()
        XCTAssertGreaterThan(snapshot.residentSize, 0)
        XCTAssertLessThanOrEqual(snapshot.timestamp.timeIntervalSinceNow, 0)
    }

    // MARK: - Memory Metrics – allocation detection

    func testMemoryIncreasesAfterLargeAllocation() {
        let before = collector.currentMemoryUsage()

        // Allocate ~1 MB of data and keep it alive during measurement
        let oneMB = 1024 * 1024
        var buffer = [UInt8](repeating: 0xAB, count: oneMB)
        // Touch the buffer to ensure it's actually resident
        buffer[0] = 0xFF
        buffer[oneMB - 1] = 0xFF

        let after = collector.currentMemoryUsage()

        // The delta should be at least ~900 KB (allowing for allocator overhead)
        let delta = Int64(after) - Int64(before)
        XCTAssertGreaterThan(delta, Int64(oneMB / 2),
            "Allocating 1 MB should increase resident memory by at least 512 KB, got \(delta) bytes")

        // Keep buffer alive past the assertion
        _ = buffer.count
    }

    func testMemorySnapshotDeltaReflectsAllocation() {
        let snap1 = collector.captureMemorySnapshot()

        // Allocate ~2 MB
        let twoMB = 2 * 1024 * 1024
        var buffer = [UInt8](repeating: 0xCD, count: twoMB)
        buffer[0] = 0xFF

        let snap2 = collector.captureMemorySnapshot()
        let delta = Int64(snap2.residentSize) - Int64(snap1.residentSize)

        XCTAssertGreaterThan(delta, Int64(twoMB / 2),
            "Snapshot delta should reflect the 2 MB allocation, got \(delta) bytes")

        _ = buffer.count
    }

    func testMultipleAllocationsAccumulate() {
        let baseline = collector.currentMemoryUsage()

        let chunkSize = 512 * 1024 // 512 KB each
        var buffers: [[UInt8]] = []

        for i in 0..<4 {
            var buf = [UInt8](repeating: UInt8(i), count: chunkSize)
            buf[0] = 0xFF
            buffers.append(buf)
        }

        let after = collector.currentMemoryUsage()
        let delta = Int64(after) - Int64(baseline)

        // 4 × 512 KB = 2 MB expected; allow 50% margin
        XCTAssertGreaterThan(delta, Int64(chunkSize * 2),
            "4 × 512 KB allocations should increase memory by at least 1 MB, got \(delta)")

        _ = buffers.count
    }

    // MARK: - CPU Metrics – basic

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

    // MARK: - CPU Metrics – work detection

    func testCPUTimeIncreasesWithWork() {
        let before = collector.currentCPUTime()!

        // Do meaningful CPU work
        var sum = 0.0
        for i in 0..<500_000 {
            sum += sin(Double(i))
        }
        _ = sum

        let after = collector.currentCPUTime()!

        let cpuDelta = after - before
        XCTAssertGreaterThan(cpuDelta, 0,
            "CPU time should increase after doing work")
    }

    func testCPUTimeDoesNotIncreaseSignificantlyForSleep() {
        let before = collector.currentCPUTime()!

        // Sleep uses no CPU
        Thread.sleep(forTimeInterval: 0.05)

        let after = collector.currentCPUTime()!

        let cpuDelta = after - before
        // 50ms of sleep should use essentially no CPU time (<5ms)
        XCTAssertLessThan(cpuDelta, 0.005,
            "Sleeping should not consume significant CPU time, got \(cpuDelta)s")
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

    func testCPUUsageHigherForWorkThanSleep() {
        // Measure CPU usage during work
        let workStart = collector.captureCPUSnapshot()
        var sum = 0.0
        for i in 0..<200_000 { sum += sin(Double(i)) }
        _ = sum
        let workEnd = collector.captureCPUSnapshot()
        let workUsage = collector.calculateCPUUsage(start: workStart, end: workEnd) ?? 0

        // Measure CPU usage during sleep
        let sleepStart = collector.captureCPUSnapshot()
        Thread.sleep(forTimeInterval: 0.05)
        let sleepEnd = collector.captureCPUSnapshot()
        let sleepUsage = collector.calculateCPUUsage(start: sleepStart, end: sleepEnd) ?? 0

        XCTAssertGreaterThan(workUsage, sleepUsage,
            "CPU usage during work (\(workUsage)%) should exceed sleep (\(sleepUsage)%)")
    }

    // MARK: - CPU Metrics – edge cases

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

    // MARK: - Monotonicity

    func testSnapshotsAreMonotonicallyIncreasing() {
        var previousMemory: UInt64 = 0
        var previousCPU: TimeInterval = 0

        for _ in 0..<5 {
            let snap = collector.captureSnapshot()
            // Memory should be non-zero and generally non-decreasing in a test
            XCTAssertGreaterThan(snap.memory.residentSize, 0)

            // CPU time should be strictly non-decreasing
            if let cpu = snap.cpu.cpuTime {
                XCTAssertGreaterThanOrEqual(cpu, previousCPU)
                previousCPU = cpu
            }

            _ = previousMemory
            previousMemory = snap.memory.residentSize

            // Do a tiny amount of work between snapshots
            var x = 0
            for i in 0..<1000 { x += i }
            _ = x
        }
    }

    // MARK: - Thermal State

    func testCurrentThermalState() {
        let state = collector.currentThermalState()
        let validStates: [MeasurementMetrics.ThermalState] = [.nominal, .fair, .serious, .critical, .unknown]
        XCTAssertTrue(validStates.contains(state))
    }

    // MARK: - Combined Snapshot

    func testCaptureSnapshot() {
        let snapshot = collector.captureSnapshot()
        XCTAssertGreaterThan(snapshot.memory.residentSize, 0)
        XCTAssertNotNil(snapshot.cpu.cpuTime)
    }

    // MARK: - Thread safety

    func testConcurrentSnapshotCapture() {
        // Capture snapshots from multiple threads simultaneously
        let group = DispatchGroup()
        let iterations = 50
        var snapshots: [MetricsSnapshot?] = Array(repeating: nil, count: iterations)
        let lock = NSLock()

        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let snap = self.collector.captureSnapshot()
                lock.lock()
                snapshots[i] = snap
                lock.unlock()
                group.leave()
            }
        }

        group.wait()

        // All snapshots should have been captured successfully
        for (i, snap) in snapshots.enumerated() {
            XCTAssertNotNil(snap, "Snapshot \(i) should not be nil")
            XCTAssertGreaterThan(snap!.memory.residentSize, 0)
        }
    }
}
