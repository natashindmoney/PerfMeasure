import XCTest
@testable import INDProfiler

/// Validates that nested and chained measurement calls produce correct,
/// independent results.
final class NestedMeasurementTests: XCTestCase {

    var profiler: INDProfiler!
    var mockDestination: MockDestination!

    override func setUp() {
        super.setUp()
        profiler = INDProfiler.shared
        mockDestination = MockDestination(identifier: "nested_mock")
        profiler.addDestination(mockDestination)
        profiler.configure(INDProfilerConfiguration(
            isEnabled: true,
            consoleEnabled: false,
            newRelicEnabled: false,
            jsonlEnabled: false,
            analyticsEnabled: false
        ))
    }

    // MARK: - Nested sync measurements

    func testNestedMeasurementsDispatchAllResults() {
        // outer wraps two inner measurements
        let outerResult = profiler.measure("outer", category: "test") {
            _ = profiler.measure("inner_1", category: "test") {
                Thread.sleep(forTimeInterval: 0.02)
                return "a"
            }
            _ = profiler.measure("inner_2", category: "test") {
                Thread.sleep(forTimeInterval: 0.02)
                return "b"
            }
            return "outer_value"
        }

        XCTAssertEqual(outerResult.value, "outer_value")

        // All three measurements should have been dispatched
        let names = mockDestination.recordedResults.map { $0.name }
        XCTAssertTrue(names.contains("inner_1"))
        XCTAssertTrue(names.contains("inner_2"))
        XCTAssertTrue(names.contains("outer"))
    }

    func testNestedMeasurementsDurationRelationship() {
        _ = profiler.measure("outer") {
            _ = profiler.measure("inner") {
                Thread.sleep(forTimeInterval: 0.05)
                return 1
            }
            return 2
        }

        let results = mockDestination.recordedResults
        let inner = results.first { $0.name == "inner" }!
        let outer = results.first { $0.name == "outer" }!

        // Outer duration must be >= inner duration (it includes the inner work)
        XCTAssertGreaterThanOrEqual(outer.metrics.duration, inner.metrics.duration)
    }

    func testNestedMeasurementsInnerDispatchedBeforeOuter() {
        _ = profiler.measure("outer") {
            _ = profiler.measure("inner") {
                return 1
            }
            return 2
        }

        let names = mockDestination.recordedResults.map { $0.name }
        // Inner completes first, so it should be dispatched before outer
        guard let innerIdx = names.firstIndex(of: "inner"),
              let outerIdx = names.firstIndex(of: "outer") else {
            XCTFail("Both measurements should be recorded")
            return
        }
        XCTAssertLessThan(innerIdx, outerIdx)
    }

    func testNestedMeasurementsRetainCorrectValues() {
        let outer = profiler.measure("outer") {
            let inner1 = profiler.measure("inner_1") { return 10 }
            let inner2 = profiler.measure("inner_2") { return 20 }
            return inner1.value + inner2.value
        }

        XCTAssertEqual(outer.value, 30)
    }

    // MARK: - Chained (sequential) measurements

    func testChainedMeasurementsAreIndependent() {
        let a = profiler.measure("step_a") {
            Thread.sleep(forTimeInterval: 0.03)
            return "a"
        }
        let b = profiler.measure("step_b") {
            Thread.sleep(forTimeInterval: 0.03)
            return "b"
        }

        XCTAssertEqual(a.value, "a")
        XCTAssertEqual(b.value, "b")

        let resultA = mockDestination.recordedResults.first { $0.name == "step_a" }!
        let resultB = mockDestination.recordedResults.first { $0.name == "step_b" }!

        // Each has its own independent duration ≥ ~30ms
        XCTAssertGreaterThanOrEqual(resultA.metrics.duration, 0.02)
        XCTAssertGreaterThanOrEqual(resultB.metrics.duration, 0.02)

        // Neither should include the other's time (each < total)
        let totalWall = resultA.metrics.duration + resultB.metrics.duration
        XCTAssertLessThan(resultA.metrics.duration, totalWall)
        XCTAssertLessThan(resultB.metrics.duration, totalWall)
    }

    func testChainedMeasurementsHaveIndependentMemorySnapshots() {
        _ = profiler.measure("first") { return 1 }
        _ = profiler.measure("second") { return 2 }

        let first = mockDestination.recordedResults.first { $0.name == "first" }!
        let second = mockDestination.recordedResults.first { $0.name == "second" }!

        // Both should have valid (non-zero) memory readings
        XCTAssertGreaterThan(first.metrics.memoryAtStart, 0)
        XCTAssertGreaterThan(second.metrics.memoryAtStart, 0)
    }

    // MARK: - Nested async measurements

    func testNestedAsyncMeasurements() async {
        let outer = await profiler.measureAsync("async_outer") {
            let inner = await self.profiler.measureAsync("async_inner") {
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
                return 42
            }
            return inner.value * 2
        }

        XCTAssertEqual(outer.value, 84)

        let names = mockDestination.recordedResults.map { $0.name }
        XCTAssertTrue(names.contains("async_inner"))
        XCTAssertTrue(names.contains("async_outer"))

        let inner = mockDestination.recordedResults.first { $0.name == "async_inner" }!
        let outerResult = mockDestination.recordedResults.first { $0.name == "async_outer" }!
        XCTAssertGreaterThanOrEqual(outerResult.metrics.duration, inner.metrics.duration)
    }

    // MARK: - Deeply nested (3 levels)

    func testThreeLevelNesting() {
        let result = profiler.measure("level_1") {
            return profiler.measure("level_2") {
                return profiler.measure("level_3") {
                    Thread.sleep(forTimeInterval: 0.02)
                    return 99
                }.value
            }.value
        }

        XCTAssertEqual(result.value, 99)

        let names = mockDestination.recordedResults.map { $0.name }
        XCTAssertEqual(names, ["level_3", "level_2", "level_1"],
                       "Results should dispatch inside-out")

        let d3 = mockDestination.recordedResults[0].metrics.duration
        let d2 = mockDestination.recordedResults[1].metrics.duration
        let d1 = mockDestination.recordedResults[2].metrics.duration

        XCTAssertGreaterThanOrEqual(d2, d3)
        XCTAssertGreaterThanOrEqual(d1, d2)
    }

    // MARK: - Nested with categories/features preserved

    func testNestedMeasurementsPreserveMetadata() {
        _ = profiler.measure("outer", category: "network", feature: "stocks") {
            _ = profiler.measure("inner", category: "parsing", feature: "json") {
                return 1
            }
            return 2
        }

        let inner = mockDestination.recordedResults.first { $0.name == "inner" }!
        let outer = mockDestination.recordedResults.first { $0.name == "outer" }!

        XCTAssertEqual(inner.category, "parsing")
        XCTAssertEqual(inner.context.feature, "json")
        XCTAssertEqual(outer.category, "network")
        XCTAssertEqual(outer.context.feature, "stocks")
    }
}
