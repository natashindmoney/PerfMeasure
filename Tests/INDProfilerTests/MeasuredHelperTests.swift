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

    // MARK: - Disabled via configuration

    func testMeasuredDisabledStillReturnsValue() {
        INDProfiler.shared.configure(INDProfilerConfiguration(isEnabled: false))

        let result = measured("disabled") {
            return 123
        }
        XCTAssertEqual(result, 123)
    }
}
