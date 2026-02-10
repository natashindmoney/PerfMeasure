import XCTest
@testable import INDProfiler

final class BaselineStoreTests: XCTestCase {

    private var store: BaselineStore!

    override func setUp() {
        super.setUp()
        store = BaselineStore.shared
        store.clearAll()
        // Wait for async clear
        Thread.sleep(forTimeInterval: 0.1)
    }

    // MARK: - Helpers

    private func makeResult(name: String, category: String = "test", duration: TimeInterval = 0.1, memoryDelta: Int64 = 100) -> MeasurementResult {
        return MeasurementResult(
            name: name,
            category: category,
            context: MeasurementContext(),
            metrics: MeasurementMetrics(
                duration: duration,
                memoryAtStart: UInt64(max(0, -memoryDelta)),
                memoryAtEnd: UInt64(max(0, memoryDelta))
            )
        )
    }

    // MARK: - Tests

    func testRecordAndRetrieveBaseline() {
        let result = makeResult(name: "op1", duration: 0.5)
        store.record(result)

        // Wait for async write
        Thread.sleep(forTimeInterval: 0.1)

        let baseline = store.baseline(name: "op1", category: "test")
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.name, "op1")
        XCTAssertEqual(baseline?.category, "test")
        XCTAssertEqual(baseline?.sampleCount, 1)
        XCTAssertEqual(baseline!.averageDuration, 0.5, accuracy: 0.001)
    }

    func testBaselineUpdatesWithMultipleSamples() {
        store.record(makeResult(name: "op2", duration: 0.1))
        store.record(makeResult(name: "op2", duration: 0.3))
        store.record(makeResult(name: "op2", duration: 0.2))

        Thread.sleep(forTimeInterval: 0.1)

        let baseline = store.baseline(name: "op2", category: "test")
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline!.sampleCount, 3)
        XCTAssertEqual(baseline!.averageDuration, 0.2, accuracy: 0.001)
        XCTAssertEqual(baseline!.minDuration, 0.1, accuracy: 0.001)
        XCTAssertEqual(baseline!.maxDuration, 0.3, accuracy: 0.001)
    }

    func testCompareRegression() {
        // Record a baseline of 0.1s
        store.record(makeResult(name: "op3", duration: 0.1))
        Thread.sleep(forTimeInterval: 0.1)

        // Now measure at 0.2s (100% increase > 20% threshold = regression)
        let current = makeResult(name: "op3", duration: 0.2)
        let comparison = store.compare(current)

        XCTAssertNotNil(comparison)
        XCTAssertEqual(comparison?.status, .regression)
        XCTAssertGreaterThan(comparison?.durationDeltaPercent ?? 0, 20)
    }

    func testCompareImprovement() {
        // Record a baseline of 0.5s
        store.record(makeResult(name: "op4", duration: 0.5))
        Thread.sleep(forTimeInterval: 0.1)

        // Now measure at 0.1s (80% decrease < -20% threshold = improvement)
        let current = makeResult(name: "op4", duration: 0.1)
        let comparison = store.compare(current)

        XCTAssertNotNil(comparison)
        XCTAssertEqual(comparison?.status, .improvement)
        XCTAssertLessThan(comparison?.durationDeltaPercent ?? 0, -20)
    }

    func testCompareWithinExpected() {
        store.record(makeResult(name: "op5", duration: 0.1))
        Thread.sleep(forTimeInterval: 0.1)

        // 10% increase is within 20% threshold
        let current = makeResult(name: "op5", duration: 0.11)
        let comparison = store.compare(current)

        XCTAssertNotNil(comparison)
        XCTAssertEqual(comparison?.status, .withinExpected)
    }

    func testCompareWithNoBaselineReturnsNil() {
        let current = makeResult(name: "no_baseline")
        let comparison = store.compare(current)
        XCTAssertNil(comparison)
    }

    func testClearBaseline() {
        store.record(makeResult(name: "op_clear"))
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertNotNil(store.baseline(name: "op_clear", category: "test"))

        store.clearBaseline(name: "op_clear", category: "test")
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertNil(store.baseline(name: "op_clear", category: "test"))
    }

    func testClearAll() {
        store.record(makeResult(name: "a"))
        store.record(makeResult(name: "b"))
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertFalse(store.allBaselines().isEmpty)

        store.clearAll()
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertTrue(store.allBaselines().isEmpty)
    }

    func testExportData() {
        store.record(makeResult(name: "export_test", duration: 0.5))
        Thread.sleep(forTimeInterval: 0.1)

        let data = store.exportData()
        XCTAssertNotNil(data)

        // Should be valid JSON
        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json)
            XCTAssertFalse(json?.isEmpty ?? true)
        }
    }

    func testImportData() throws {
        store.record(makeResult(name: "import_source", duration: 0.3))
        Thread.sleep(forTimeInterval: 0.1)

        guard let data = store.exportData() else {
            XCTFail("Export failed")
            return
        }

        store.clearAll()
        Thread.sleep(forTimeInterval: 0.1)

        try store.importData(data)
        Thread.sleep(forTimeInterval: 0.1)

        let baseline = store.baseline(name: "import_source", category: "test")
        XCTAssertNotNil(baseline)
    }
}
