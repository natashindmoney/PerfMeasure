//
//  AnalyticsPerfDestination.swift
//  PerfMeasure
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Destination that forwards measurements to a host-provided analytics writer (e.g., AutoTracker).
public final class AnalyticsPerfDestination: BasePerfMeasureDestination {

    public static let destinationId = "analytics"

    public init(isEnabled: Bool = true) {
        super.init(identifier: Self.destinationId, isEnabled: isEnabled, qos: .utility)
    }

    override public func performRecord(_ result: MeasurementResult) {
        PerfMeasureDependencies.analyticsWriter?.record(measurement: result)
    }
}
