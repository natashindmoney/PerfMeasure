//
//  INDProfilerDependencies.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Defines integration points that the host application can provide to extend INDProfiler.
/// These should be set once at app startup before using INDProfiler.
public enum INDProfilerDependencies {

    /// Provides feature-flag values for configuring INDProfiler dynamically.
    /// Set this once at app startup.
    public static var featureFlagProvider: INDProfilerFeatureFlagProviding?

    /// Sends tech events (e.g., to NewRelic) for measurements routed through the reporter destination.
    /// Set this once at app startup.
    public static var eventReporter: INDProfilerEventReporting?

    /// Writes raw measurement payloads to a custom analytics sink (e.g., AutoTracker).
    /// Set this once at app startup.
    public static var analyticsWriter: INDProfilerAnalyticsWriting?
}

/// Supplies remote-config / feature-flag state for INDProfiler.
public protocol INDProfilerFeatureFlagProviding: AnyObject {
    func isProfilerEnabled() -> Bool
    func isConsoleLoggingEnabled() -> Bool
    func isNewRelicReportingEnabled() -> Bool
    func isJSONLExportEnabled() -> Bool
    func isAnalyticsWriterEnabled() -> Bool
}

/// Sends measurement payloads to an external analytics pipeline (e.g., NewRelic).
public protocol INDProfilerEventReporting: AnyObject {
    func sendEvent(name: String, category: String, properties: [String: Any])
}

/// Persists measurement results to a custom sink (e.g., AutoTracker/EventFileWriter).
public protocol INDProfilerAnalyticsWriting: AnyObject {
    func record(measurement: MeasurementResult)
}
