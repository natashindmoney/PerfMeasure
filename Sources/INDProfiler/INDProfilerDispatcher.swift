//
//  INDProfilerDispatcher.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Routes measurement results to configured destinations.
///
/// Thread safety is implemented with `NSLock` rather than a concurrent
/// `DispatchQueue` — the lock-hold time is just an array-copy (COW
/// reference-count bump ≈ 5 ns), so the hot-path overhead is minimal.
public final class INDProfilerDispatcher {

    private var destinations: [INDProfilerDestination] = []
    private let lock = NSLock()

    public init() {}

    // MARK: - Destination Management

    /// Adds a destination for receiving measurement results
    public func addDestination(_ destination: INDProfilerDestination) {
        lock.lock()
        destinations.append(destination)
        lock.unlock()
    }

    /// Removes a destination by its identifier
    public func removeDestination(identifier: String) {
        lock.lock()
        destinations.removeAll { $0.identifier == identifier }
        lock.unlock()
    }

    /// Returns all registered destinations
    public func allDestinations() -> [INDProfilerDestination] {
        lock.lock()
        let copy = destinations
        lock.unlock()
        return copy
    }

    /// Enables or disables a destination by identifier
    public func setDestinationEnabled(_ identifier: String, enabled: Bool) {
        lock.lock()
        for i in destinations.indices {
            if destinations[i].identifier == identifier {
                destinations[i].isEnabled = enabled
                break
            }
        }
        lock.unlock()
    }

    // MARK: - Dispatching

    /// Dispatches a measurement result to all enabled destinations.
    ///
    /// Acquires the lock only long enough to snapshot the destination list
    /// (a COW array copy).  Each destination's `record()` method handles
    /// its own background dispatch internally.
    public func dispatch(_ result: MeasurementResult) {
        lock.lock()
        let current = destinations
        lock.unlock()

        for destination in current where destination.isEnabled {
            destination.record(result)
        }
    }
}
