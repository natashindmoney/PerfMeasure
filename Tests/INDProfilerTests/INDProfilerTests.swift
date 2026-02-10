import XCTest
@testable import INDProfiler

// MARK: - Test Helpers

/// A mock destination that captures recorded results
final class MockDestination: INDProfilerDestination {
    let identifier: String
    var isEnabled: Bool
    var recordedResults: [MeasurementResult] = []
    private let lock = NSLock()

    init(identifier: String = "mock", isEnabled: Bool = true) {
        self.identifier = identifier
        self.isEnabled = isEnabled
    }

    func record(_ result: MeasurementResult) {
        lock.lock()
        recordedResults.append(result)
        lock.unlock()
    }

    var lastResult: MeasurementResult? {
        lock.lock()
        defer { lock.unlock() }
        return recordedResults.last
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedResults.count
    }
}

// MARK: - INDProfiler Core Tests

final class INDProfilerTests: XCTestCase {

    var profiler: INDProfiler!
    var mockDestination: MockDestination!

    override func setUp() {
        super.setUp()
        profiler = INDProfiler.shared
        mockDestination = MockDestination()
        profiler.addDestination(mockDestination)
        profiler.configure(INDProfilerConfiguration(
            isEnabled: true,
            consoleEnabled: false,
            newRelicEnabled: false,
            jsonlEnabled: false,
            analyticsEnabled: false
        ))
    }

    // MARK: - Sync Measurement

    func testMeasureSyncReturnsValue() {
        let result = profiler.measure("test_sync") {
            return 42
        }
        XCTAssertEqual(result.value, 42)
    }

    func testMeasureSyncCapturesDuration() {
        let result = profiler.measure("test_duration") {
            Thread.sleep(forTimeInterval: 0.05)
            return "done"
        }

        XCTAssertNotNil(result.measurement)
        XCTAssertGreaterThanOrEqual(result.measurement!.metrics.duration, 0.04)
    }

    func testMeasureSyncCapturesName() {
        _ = profiler.measure("my_operation") { return 1 }

        let recorded = mockDestination.lastResult
        XCTAssertNotNil(recorded)
        XCTAssertEqual(recorded?.name, "my_operation")
    }

    func testMeasureSyncCapturesCategoryDefault() {
        _ = profiler.measure("op") { return 1 }

        let recorded = mockDestination.lastResult
        XCTAssertEqual(recorded?.category, "general")
    }

    func testMeasureSyncCapturesCategoryCustom() {
        _ = profiler.measure("op", category: "network") { return 1 }

        let recorded = mockDestination.lastResult
        XCTAssertEqual(recorded?.category, "network")
    }

    func testMeasureSyncCapturesFeatureTag() {
        _ = profiler.measure("op", feature: "stocks") { return 1 }

        let recorded = mockDestination.lastResult
        XCTAssertEqual(recorded?.context.feature, "stocks")
    }

    func testMeasureSyncCapturesPRNumber() {
        _ = profiler.measure("op", prNumber: "PR-456") { return 1 }

        let recorded = mockDestination.lastResult
        XCTAssertEqual(recorded?.context.prNumber, "PR-456")
    }

    func testMeasureSyncCapturesMemory() {
        let result = profiler.measure("mem_test") { return 1 }

        XCTAssertNotNil(result.measurement)
        XCTAssertGreaterThan(result.measurement!.metrics.memoryAtStart, 0)
        XCTAssertGreaterThan(result.measurement!.metrics.memoryAtEnd, 0)
    }

    func testMeasureSyncWithThrowingOperation() throws {
        let result = try profiler.measure("throwing_op") {
            return try JSONDecoder().decode([String].self, from: "[\"a\",\"b\"]".data(using: .utf8)!)
        }
        XCTAssertEqual(result.value, ["a", "b"])
    }

    func testMeasureSyncDisabledReturnsValueWithoutMeasurement() {
        profiler.configure(INDProfilerConfiguration(isEnabled: false))

        let initialCount = mockDestination.count
        let result = profiler.measure("disabled_test") { return 99 }

        XCTAssertEqual(result.value, 99)
        XCTAssertNil(result.measurement)
        XCTAssertEqual(mockDestination.count, initialCount)
    }

    // MARK: - Async Measurement

    func testMeasureAsyncReturnsValue() async {
        let result = await profiler.measureAsync("test_async") {
            return 84
        }
        XCTAssertEqual(result.value, 84)
    }

    func testMeasureAsyncCapturesDuration() async {
        let result = await profiler.measureAsync("async_duration") {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            return "done"
        }

        XCTAssertNotNil(result.measurement)
        XCTAssertGreaterThanOrEqual(result.measurement!.metrics.duration, 0.04)
    }

    func testMeasureAsyncDisabledReturnsValueWithoutMeasurement() async {
        profiler.configure(INDProfilerConfiguration(isEnabled: false))

        let initialCount = mockDestination.count
        let result = await profiler.measureAsync("disabled_async") { return 77 }

        XCTAssertEqual(result.value, 77)
        XCTAssertNil(result.measurement)
        XCTAssertEqual(mockDestination.count, initialCount)
    }

    // MARK: - Manual Token Measurement

    func testTokenMeasurement() {
        let token = profiler.start("token_test", category: "test")

        Thread.sleep(forTimeInterval: 0.05)
        let result = token.stop()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "token_test")
        XCTAssertEqual(result?.category, "test")
        XCTAssertGreaterThanOrEqual(result!.metrics.duration, 0.04)
    }

    func testTokenCheckpoints() {
        let token = profiler.start("checkpoint_test")

        Thread.sleep(forTimeInterval: 0.02)
        token.checkpoint("phase_1")

        Thread.sleep(forTimeInterval: 0.02)
        token.checkpoint("phase_2")

        let result = token.stop()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.metrics.checkpoints.count, 2)
        XCTAssertEqual(result?.metrics.checkpoints[0].name, "phase_1")
        XCTAssertEqual(result?.metrics.checkpoints[1].name, "phase_2")
        XCTAssertLessThan(
            result!.metrics.checkpoints[0].elapsedTime,
            result!.metrics.checkpoints[1].elapsedTime
        )
    }

    func testTokenStopTwiceReturnsNilSecondTime() {
        let token = profiler.start("double_stop")
        let first = token.stop()
        let second = token.stop()

        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func testTokenElapsedTime() {
        let token = profiler.start("elapsed_test")
        Thread.sleep(forTimeInterval: 0.05)
        let elapsed = token.elapsedTime
        XCTAssertGreaterThanOrEqual(elapsed, 0.04)
    }

    func testTokenDisabledReturnsNil() {
        profiler.configure(INDProfilerConfiguration(isEnabled: false))

        let token = profiler.start("disabled_token")
        let result = token.stop()
        XCTAssertNil(result)
    }

    // MARK: - Configuration

    func testConfigureUpdatesState() {
        let config = INDProfilerConfiguration(
            isEnabled: true,
            consoleEnabled: true,
            defaultCategory: "custom_default"
        )
        profiler.configure(config)

        XCTAssertTrue(profiler.configuration.isEnabled)
        XCTAssertTrue(profiler.configuration.consoleEnabled)
        XCTAssertEqual(profiler.configuration.defaultCategory, "custom_default")
    }

    func testDefaultCategoryAppliedWhenNoCategoryProvided() {
        profiler.configure(INDProfilerConfiguration(
            isEnabled: true,
            consoleEnabled: false,
            newRelicEnabled: false,
            jsonlEnabled: false,
            defaultCategory: "my_category"
        ))

        _ = profiler.measure("no_category") { return 1 }

        let recorded = mockDestination.lastResult
        XCTAssertEqual(recorded?.category, "my_category")
    }
}
