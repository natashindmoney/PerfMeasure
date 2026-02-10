import XCTest
@testable import INDProfiler

final class ModelTests: XCTestCase {

    // MARK: - MeasurementContext

    func testContextCapturesSourceLocation() {
        let context = MeasurementContext(
            file: "TestFile.swift",
            function: "testFunc()",
            line: 42
        )
        XCTAssertEqual(context.file, "TestFile.swift")
        XCTAssertEqual(context.function, "testFunc()")
        XCTAssertEqual(context.line, 42)
    }

    func testContextCapturesOptionalTags() {
        let context = MeasurementContext(
            feature: "stocks",
            experiment: "exp-001",
            prNumber: "PR-123",
            variant: "variant-A",
            customTags: ["key": "value"]
        )
        XCTAssertEqual(context.feature, "stocks")
        XCTAssertEqual(context.experiment, "exp-001")
        XCTAssertEqual(context.prNumber, "PR-123")
        XCTAssertEqual(context.variant, "variant-A")
        XCTAssertEqual(context.customTags?["key"], "value")
    }

    func testContextToDictionary() {
        let context = MeasurementContext(feature: "payments")
        let dict = context.toDictionary()

        XCTAssertNotNil(dict["file"])
        XCTAssertNotNil(dict["function"])
        XCTAssertNotNil(dict["line"])
        XCTAssertNotNil(dict["build_type"])
        XCTAssertNotNil(dict["session_id"])
        XCTAssertNotNil(dict["timestamp"])
        XCTAssertEqual(dict["feature"] as? String, "payments")
    }

    func testContextSessionIdIsStable() {
        let c1 = MeasurementContext()
        let c2 = MeasurementContext()
        XCTAssertEqual(c1.sessionId, c2.sessionId, "Session ID should be the same within a process")
    }

    func testContextBuildType() {
        let buildType = MeasurementContext.BuildType.current
        #if DEBUG
        XCTAssertEqual(buildType, .debug)
        #endif
    }

    // MARK: - MeasurementMetrics

    func testMetricsMemoryDelta() {
        let metrics = MeasurementMetrics(
            duration: 1.0,
            memoryAtStart: 1000,
            memoryAtEnd: 1500
        )
        XCTAssertEqual(metrics.memoryDelta, 500)
    }

    func testMetricsNegativeMemoryDelta() {
        let metrics = MeasurementMetrics(
            duration: 1.0,
            memoryAtStart: 2000,
            memoryAtEnd: 1500
        )
        XCTAssertEqual(metrics.memoryDelta, -500)
    }

    func testMetricsFormattedDurationMicroseconds() {
        let metrics = MeasurementMetrics(duration: 0.0005, memoryAtStart: 0, memoryAtEnd: 0)
        XCTAssertTrue(metrics.formattedDuration.contains("µs"))
    }

    func testMetricsFormattedDurationMilliseconds() {
        let metrics = MeasurementMetrics(duration: 0.05, memoryAtStart: 0, memoryAtEnd: 0)
        XCTAssertTrue(metrics.formattedDuration.contains("ms"))
    }

    func testMetricsFormattedDurationSeconds() {
        let metrics = MeasurementMetrics(duration: 2.5, memoryAtStart: 0, memoryAtEnd: 0)
        XCTAssertTrue(metrics.formattedDuration.contains("s"))
    }

    func testMetricsFormattedMemoryDeltaBytes() {
        let metrics = MeasurementMetrics(duration: 0, memoryAtStart: 0, memoryAtEnd: 500)
        XCTAssertEqual(metrics.formattedMemoryDelta, "+500 B")
    }

    func testMetricsFormattedMemoryDeltaKB() {
        let metrics = MeasurementMetrics(duration: 0, memoryAtStart: 0, memoryAtEnd: 2048)
        XCTAssertTrue(metrics.formattedMemoryDelta.contains("KB"))
    }

    func testMetricsFormattedMemoryDeltaMB() {
        let metrics = MeasurementMetrics(duration: 0, memoryAtStart: 0, memoryAtEnd: 2 * 1024 * 1024)
        XCTAssertTrue(metrics.formattedMemoryDelta.contains("MB"))
    }

    func testMetricsToDictionary() {
        let metrics = MeasurementMetrics(
            duration: 0.5,
            memoryAtStart: 1000,
            memoryAtEnd: 2000,
            cpuUsagePercent: 25.0,
            cpuTime: 0.1
        )
        let dict = metrics.toDictionary()

        XCTAssertEqual(dict["duration_ms"] as? Double, 500.0)
        XCTAssertEqual(dict["memory_at_start_bytes"] as? UInt64, 1000)
        XCTAssertEqual(dict["memory_at_end_bytes"] as? UInt64, 2000)
        XCTAssertEqual(dict["memory_delta_bytes"] as? Int64, 1000)
        XCTAssertEqual(dict["cpu_usage_percent"] as? Double, 25.0)
        XCTAssertEqual(dict["cpu_time_ms"] as? Double, 100.0)
    }

    func testMetricsCheckpoint() {
        let checkpoint = MeasurementMetrics.Checkpoint(name: "step1", elapsedTime: 0.5)
        XCTAssertEqual(checkpoint.name, "step1")
        XCTAssertEqual(checkpoint.elapsedTime, 0.5)
    }

    func testMetricsThermalStateFromProcessInfo() {
        let nominal = MeasurementMetrics.ThermalState(from: .nominal)
        XCTAssertEqual(nominal, .nominal)

        let fair = MeasurementMetrics.ThermalState(from: .fair)
        XCTAssertEqual(fair, .fair)

        let serious = MeasurementMetrics.ThermalState(from: .serious)
        XCTAssertEqual(serious, .serious)

        let critical = MeasurementMetrics.ThermalState(from: .critical)
        XCTAssertEqual(critical, .critical)
    }

    // MARK: - MeasurementResult

    func testResultToDictionary() {
        let result = MeasurementResult(
            name: "op",
            category: "test",
            context: MeasurementContext(feature: "feat"),
            metrics: MeasurementMetrics(duration: 0.1, memoryAtStart: 100, memoryAtEnd: 200)
        )
        let dict = result.toDictionary()

        XCTAssertEqual(dict["name"] as? String, "op")
        XCTAssertEqual(dict["category"] as? String, "test")
        XCTAssertNotNil(dict["id"])
        XCTAssertEqual(dict["duration_ms"] as? Double, 100.0)
        XCTAssertEqual(dict["ctx_feature"] as? String, "feat")
    }

    func testResultConsoleDescription() {
        let result = MeasurementResult(
            name: "parseJSON",
            category: "parsing",
            context: MeasurementContext(feature: "stocks", prNumber: "PR-99"),
            metrics: MeasurementMetrics(
                duration: 0.05,
                memoryAtStart: 1000,
                memoryAtEnd: 2000,
                cpuUsagePercent: 30.0
            )
        )
        let desc = result.consoleDescription

        XCTAssertTrue(desc.contains("[parsing] parseJSON"))
        XCTAssertTrue(desc.contains("Duration:"))
        XCTAssertTrue(desc.contains("Memory:"))
        XCTAssertTrue(desc.contains("CPU:"))
        XCTAssertTrue(desc.contains("Feature: stocks"))
        XCTAssertTrue(desc.contains("PR: PR-99"))
    }

    // MARK: - MeasuredValue / MeasuredAsyncValue

    func testMeasuredValueStoresValueAndMeasurement() {
        let result = MeasurementResult(
            name: "test",
            category: "test",
            context: MeasurementContext(),
            metrics: MeasurementMetrics(duration: 0.1, memoryAtStart: 0, memoryAtEnd: 0)
        )
        let mv = MeasuredValue(value: "hello", measurement: result)
        XCTAssertEqual(mv.value, "hello")
        XCTAssertNotNil(mv.measurement)
    }

    func testMeasuredValueWithNilMeasurement() {
        let mv = MeasuredValue(value: 42, measurement: nil)
        XCTAssertEqual(mv.value, 42)
        XCTAssertNil(mv.measurement)
    }

    func testMeasuredAsyncValueStoresValueAndMeasurement() {
        let mav = MeasuredAsyncValue(value: [1, 2, 3], measurement: nil)
        XCTAssertEqual(mav.value, [1, 2, 3])
        XCTAssertNil(mav.measurement)
    }
}
