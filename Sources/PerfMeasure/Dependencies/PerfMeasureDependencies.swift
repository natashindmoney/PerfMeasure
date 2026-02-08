//
//  PerfMeasureDependencies.swift
//  PerfMeasure
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Defines integration points that the host application can provide to extend PerfMeasure.
/// These should be set once at app startup before using PerfMeasure.
public enum PerfMeasureDependencies {

    /// Provides feature-flag values for configuring PerfMeasure dynamically.
    /// Set this once at app startup.
    nonisolated(unsafe) public static var featureFlagProvider: PerfMeasureFeatureFlagProviding?

    /// Sends tech events (e.g., to NewRelic) for measurements routed through the reporter destination.
    /// Set this once at app startup.
    nonisolated(unsafe) public static var eventReporter: PerfMeasureEventReporting?

    /// Writes raw measurement payloads to a custom analytics sink (e.g., AutoTracker).
    /// Set this once at app startup.
    nonisolated(unsafe) public static var analyticsWriter: PerfMeasureAnalyticsWriting?
}

/// Supplies remote-config / feature-flag state for PerfMeasure.
public protocol PerfMeasureFeatureFlagProviding: AnyObject {
    func isPerfMeasureEnabled() -> Bool
    func isConsoleLoggingEnabled() -> Bool
    func isNewRelicReportingEnabled() -> Bool
    func isJSONLExportEnabled() -> Bool
    func isAnalyticsWriterEnabled() -> Bool
}

/// Sends measurement payloads to an external analytics pipeline (e.g., NewRelic).
public protocol PerfMeasureEventReporting: AnyObject {
    func sendEvent(name: String, category: String, properties: [String: Any])
}

/// Persists measurement results to a custom sink (e.g., AutoTracker/EventFileWriter).
public protocol PerfMeasureAnalyticsWriting: AnyObject {
    func record(measurement: MeasurementResult)
}
