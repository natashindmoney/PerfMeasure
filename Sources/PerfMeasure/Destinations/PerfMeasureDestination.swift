//
//  PerfMeasureDestination.swift
//  INDCommon
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Protocol for performance measurement output destinations
public protocol PerfMeasureDestination {
    /// Unique identifier for this destination
    var identifier: String { get }

    /// Whether this destination is currently enabled
    var isEnabled: Bool { get set }

    /// Records a measurement result
    func record(_ result: MeasurementResult)
}

/// Base class for destinations that need thread-safe operation
open class BasePerfMeasureDestination: PerfMeasureDestination {
    public let identifier: String
    public var isEnabled: Bool

    private let queue: DispatchQueue

    public init(identifier: String, isEnabled: Bool = true, qos: DispatchQoS = .utility) {
        self.identifier = identifier
        self.isEnabled = isEnabled
        self.queue = DispatchQueue(
            label: "com.indmoney.perfmeasure.\(identifier)",
            qos: qos
        )
    }

    public final func record(_ result: MeasurementResult) {
        guard isEnabled else { return }
        queue.async { [weak self] in
            self?.performRecord(result)
        }
    }

    /// Override this method to implement the actual recording logic
    /// This method is always called on a background queue
    open func performRecord(_ result: MeasurementResult) {
        // Subclasses override this
    }
}
