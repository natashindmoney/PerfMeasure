//
//  PerfMeasureDispatcher.swift
//  INDCommon
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Routes measurement results to configured destinations
public final class PerfMeasureDispatcher: @unchecked Sendable {

    private var destinations: [PerfMeasureDestination] = []
    private let queue = DispatchQueue(
        label: "com.indmoney.perfmeasure.dispatcher",
        qos: .utility,
        attributes: .concurrent
    )

    public init() {}

    // MARK: - Destination Management

    /// Adds a destination for receiving measurement results
    public func addDestination(_ destination: PerfMeasureDestination) {
        queue.async(flags: .barrier) { [weak self] in
            self?.destinations.append(destination)
        }
    }

    /// Removes a destination by its identifier
    public func removeDestination(identifier: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.destinations.removeAll { $0.identifier == identifier }
        }
    }

    /// Returns all registered destinations
    public func allDestinations() -> [PerfMeasureDestination] {
        return queue.sync {
            return destinations
        }
    }

    /// Enables or disables a destination by identifier
    public func setDestinationEnabled(_ identifier: String, enabled: Bool) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            for i in self.destinations.indices {
                if self.destinations[i].identifier == identifier {
                    self.destinations[i].isEnabled = enabled
                    break
                }
            }
        }
    }

    // MARK: - Dispatching

    /// Dispatches a measurement result to all enabled destinations
    public func dispatch(_ result: MeasurementResult) {
        let currentDestinations = queue.sync { destinations }
        for destination in currentDestinations where destination.isEnabled {
            destination.record(result)
        }
    }
}
