import XCTest
@testable import INDProfiler

final class ConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = INDProfilerConfiguration()
        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.consoleEnabled)
        XCTAssertTrue(config.newRelicEnabled)
        XCTAssertTrue(config.jsonlEnabled)
        XCTAssertFalse(config.analyticsEnabled)
        XCTAssertEqual(config.consoleThreshold, 0.001)
        XCTAssertTrue(config.includeMemoryMetrics)
        XCTAssertTrue(config.includeCPUMetrics)
        XCTAssertEqual(config.defaultCategory, "general")
    }

    func testDebugPreset() {
        let config = INDProfilerConfiguration.debug
        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.consoleEnabled)
        XCTAssertFalse(config.newRelicEnabled)
        XCTAssertTrue(config.jsonlEnabled)
        XCTAssertTrue(config.analyticsEnabled)
        XCTAssertEqual(config.consoleThreshold, 0)
    }

    func testReleasePreset() {
        let config = INDProfilerConfiguration.release
        XCTAssertTrue(config.isEnabled)
        XCTAssertFalse(config.consoleEnabled)
        XCTAssertTrue(config.newRelicEnabled)
        XCTAssertFalse(config.jsonlEnabled)
        XCTAssertFalse(config.analyticsEnabled)
        XCTAssertEqual(config.consoleThreshold, 0.1)
    }

    func testDisabledPreset() {
        let config = INDProfilerConfiguration.disabled
        XCTAssertFalse(config.isEnabled)
    }

    func testCustomConfiguration() {
        let config = INDProfilerConfiguration(
            isEnabled: true,
            consoleEnabled: false,
            newRelicEnabled: false,
            jsonlEnabled: false,
            analyticsEnabled: true,
            consoleThreshold: 0.5,
            includeMemoryMetrics: false,
            includeCPUMetrics: false,
            defaultCategory: "custom"
        )
        XCTAssertTrue(config.isEnabled)
        XCTAssertFalse(config.consoleEnabled)
        XCTAssertFalse(config.newRelicEnabled)
        XCTAssertFalse(config.jsonlEnabled)
        XCTAssertTrue(config.analyticsEnabled)
        XCTAssertEqual(config.consoleThreshold, 0.5)
        XCTAssertFalse(config.includeMemoryMetrics)
        XCTAssertFalse(config.includeCPUMetrics)
        XCTAssertEqual(config.defaultCategory, "custom")
    }

    func testFromFeatureFlagsWithNoProvider() {
        // With no provider set, should return default config
        INDProfilerDependencies.featureFlagProvider = nil
        let config = INDProfilerConfiguration.fromFeatureFlags()
        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.consoleEnabled)
    }
}
