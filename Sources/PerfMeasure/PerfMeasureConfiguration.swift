//
//  PerfMeasureConfiguration.swift
//  INDCommon
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Configuration for the PerfMeasure system
public struct PerfMeasureConfiguration {

    /// Whether PerfMeasure is globally enabled
    public var isEnabled: Bool

    /// Whether console logging is enabled
    public var consoleEnabled: Bool

    /// Whether NewRelic reporting is enabled
    public var newRelicEnabled: Bool

    /// Whether JSONL file logging is enabled
    public var jsonlEnabled: Bool

    /// Whether analytics writer destination is enabled
    public var analyticsEnabled: Bool

    /// Minimum duration threshold (in seconds) for console logging
    /// Measurements faster than this won't be logged to console
    public var consoleThreshold: TimeInterval

    /// Whether to include memory metrics
    public var includeMemoryMetrics: Bool

    /// Whether to include CPU metrics
    public var includeCPUMetrics: Bool

    /// Default category for measurements without an explicit category
    public var defaultCategory: String

    // MARK: - Initialization

    public init(
        isEnabled: Bool = true,
        consoleEnabled: Bool = true,
        newRelicEnabled: Bool = true,
        jsonlEnabled: Bool = true,
        analyticsEnabled: Bool = false,
        consoleThreshold: TimeInterval = 0.001,
        includeMemoryMetrics: Bool = true,
        includeCPUMetrics: Bool = true,
        defaultCategory: String = "general"
    ) {
        self.isEnabled = isEnabled
        self.consoleEnabled = consoleEnabled
        self.newRelicEnabled = newRelicEnabled
        self.jsonlEnabled = jsonlEnabled
        self.analyticsEnabled = analyticsEnabled
        self.consoleThreshold = consoleThreshold
        self.includeMemoryMetrics = includeMemoryMetrics
        self.includeCPUMetrics = includeCPUMetrics
        self.defaultCategory = defaultCategory
    }

    // MARK: - Feature Flag Integration

    /// Creates configuration from feature flags
    public static func fromFeatureFlags() -> PerfMeasureConfiguration {
        guard let provider = PerfMeasureDependencies.featureFlagProvider else {
            return PerfMeasureConfiguration()
        }

        return PerfMeasureConfiguration(
            isEnabled: provider.isPerfMeasureEnabled(),
            consoleEnabled: provider.isConsoleLoggingEnabled(),
            newRelicEnabled: provider.isNewRelicReportingEnabled(),
            jsonlEnabled: provider.isJSONLExportEnabled(),
            analyticsEnabled: provider.isAnalyticsWriterEnabled()
        )
    }

    // MARK: - Presets

    /// Debug configuration with all features enabled
    public static var debug: PerfMeasureConfiguration {
        return PerfMeasureConfiguration(
            isEnabled: true,
            consoleEnabled: true,
            newRelicEnabled: false,
            jsonlEnabled: true,
            analyticsEnabled: true,
            consoleThreshold: 0
        )
    }

    /// Release configuration with minimal overhead
    public static var release: PerfMeasureConfiguration {
        return PerfMeasureConfiguration(
            isEnabled: true,
            consoleEnabled: false,
            newRelicEnabled: true,
            jsonlEnabled: false,
            analyticsEnabled: false,
            consoleThreshold: 0.1
        )
    }

    /// Disabled configuration
    public static var disabled: PerfMeasureConfiguration {
        return PerfMeasureConfiguration(isEnabled: false)
    }
}
