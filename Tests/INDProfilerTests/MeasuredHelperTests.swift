import XCTest
@testable import INDProfiler

final class MeasuredHelperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        INDProfiler.shared.configure(INDProfilerConfiguration(
            isEnabled: true,
            consoleEnabled: false,
            newRelicEnabled: false,
            jsonlEnabled: false,
            analyticsEnabled: false
        ))
    }

    // MARK: - measured() sync helper

    func testMeasuredReturnsValue() {
        let result = measured("helper_test") {
            return 42
        }
        XCTAssertEqual(result, 42)
    }

    func testMeasuredWithCategoryAndFeature() {
        let result = measured("helper_cat", category: "parsing", feature: "stocks") {
            return "hello"
        }
        XCTAssertEqual(result, "hello")
    }

    func testMeasuredWithThrowingOperation() throws {
        let data = "[1,2,3]".data(using: .utf8)!
        let result = try measured("throwing_helper") {
            return try JSONDecoder().decode([Int].self, from: data)
        }
        XCTAssertEqual(result, [1, 2, 3])
    }

    // MARK: - measuredAsync() async helper

    func testMeasuredAsyncReturnsValue() async {
        let result = await measuredAsync("async_helper") {
            return 84
        }
        XCTAssertEqual(result, 84)
    }

    // MARK: - measuredWithResult() sync helper

    func testMeasuredWithResultReturnsValueAndMeasurement() {
        let result = measuredWithResult("result_helper") {
            return 99
        }
        XCTAssertEqual(result.value, 99)
        XCTAssertNotNil(result.measurement)
        XCTAssertEqual(result.measurement?.name, "result_helper")
    }

    // MARK: - measuredAsyncWithResult() async helper

    func testMeasuredAsyncWithResultReturnsValueAndMeasurement() async {
        let result = await measuredAsyncWithResult("async_result_helper") {
            return "async_value"
        }
        XCTAssertEqual(result.value, "async_value")
        XCTAssertNotNil(result.measurement)
        XCTAssertEqual(result.measurement?.name, "async_result_helper")
    }

    // MARK: - Disabled

    func testMeasuredDisabledStillReturnsValue() {
        INDProfiler.shared.configure(INDProfilerConfiguration(isEnabled: false))

        let result = measured("disabled") {
            return 123
        }
        XCTAssertEqual(result, 123)
    }

    func testMeasuredWithResultDisabledReturnsNilMeasurement() {
        INDProfiler.shared.configure(INDProfilerConfiguration(isEnabled: false))

        let result = measuredWithResult("disabled_result") {
            return 456
        }
        XCTAssertEqual(result.value, 456)
        XCTAssertNil(result.measurement)
    }
}
