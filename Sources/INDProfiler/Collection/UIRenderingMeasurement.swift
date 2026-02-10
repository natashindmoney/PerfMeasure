//
//  UIRenderingMeasurement.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

#if canImport(UIKit)
import Foundation
import UIKit
import QuartzCore

/// Measures UI rendering performance including frame rate and dropped frames
public final class UIRenderingMeasurement {

    public let name: String
    public let category: String

    private let context: MeasurementContext
    private let metricsCollector: MetricsCollector
    private let dispatcher: INDProfilerDispatcher
    private let isEnabled: Bool

    private var displayLink: CADisplayLink?
    private var startSnapshot: MetricsSnapshot?
    private var startTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var droppedFrames: Int = 0
    private var frozenFrames: Int = 0
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var isRunning = false
    private let lock = NSLock()

    // Frame timing thresholds
    private let targetFrameDuration: CFTimeInterval = 1.0 / 60.0 // 16.67ms for 60fps
    private let droppedFrameThreshold: CFTimeInterval = 1.0 / 30.0 // 33ms - more than 2 frames
    private let frozenFrameThreshold: CFTimeInterval = 0.7 // 700ms

    init(
        name: String,
        category: String,
        context: MeasurementContext,
        metricsCollector: MetricsCollector,
        dispatcher: INDProfilerDispatcher,
        isEnabled: Bool
    ) {
        self.name = name
        self.category = category
        self.context = context
        self.metricsCollector = metricsCollector
        self.dispatcher = dispatcher
        self.isEnabled = isEnabled
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Starts measuring UI rendering
    public func start() {
        guard isEnabled else { return }

        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return }
        isRunning = true

        startSnapshot = metricsCollector.captureSnapshot()
        frameCount = 0
        droppedFrames = 0
        frozenFrames = 0
        lastFrameTimestamp = 0

        DispatchQueue.main.async { [weak self] in
            self?.setupDisplayLink()
        }
    }

    /// Stops measuring and returns the result
    @discardableResult
    public func stop() -> MeasurementResult? {
        guard isEnabled else { return nil }

        lock.lock()
        defer { lock.unlock() }

        guard isRunning else { return nil }
        isRunning = false

        displayLink?.invalidate()
        displayLink = nil

        guard let startSnapshot = startSnapshot else { return nil }

        let endSnapshot = metricsCollector.captureSnapshot()
        let duration = CACurrentMediaTime() - startTime
        let cpuUsage = metricsCollector.calculateCPUUsage(start: startSnapshot.cpu, end: endSnapshot.cpu)

        let averageFPS: Double
        if duration > 0 {
            averageFPS = Double(frameCount) / duration
        } else {
            averageFPS = 0
        }

        let metrics = MeasurementMetrics(
            duration: duration,
            memoryAtStart: startSnapshot.memory.residentSize,
            memoryAtEnd: endSnapshot.memory.residentSize,
            cpuUsagePercent: cpuUsage,
            framesRendered: frameCount,
            droppedFrames: droppedFrames,
            frozenFrames: frozenFrames,
            averageFPS: averageFPS,
            thermalState: endSnapshot.thermalState
        )

        let result = MeasurementResult(
            name: name,
            category: category,
            context: context,
            metrics: metrics
        )

        dispatcher.dispatch(result)

        return result
    }

    // MARK: - Private

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        displayLink?.add(to: .main, forMode: .common)
        startTime = CACurrentMediaTime()
        lastFrameTimestamp = startTime
    }

    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        lock.lock()
        defer { lock.unlock() }

        guard isRunning else { return }

        let currentTimestamp = displayLink.timestamp
        let frameDuration = currentTimestamp - lastFrameTimestamp

        frameCount += 1

        // Check for dropped frames (more than 2x target frame duration)
        if frameDuration > droppedFrameThreshold {
            let missedFrames = Int(frameDuration / targetFrameDuration) - 1
            droppedFrames += max(0, missedFrames)
        }

        // Check for frozen frames (>700ms)
        if frameDuration > frozenFrameThreshold {
            frozenFrames += 1
        }

        lastFrameTimestamp = currentTimestamp
    }
}

// MARK: - Convenience Extension

public extension INDProfiler {

    /// Measures UI rendering for a specific duration
    func measureRenderingFor(
        seconds: TimeInterval,
        name: String,
        category: String = "rendering",
        feature: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        completion: @escaping (MeasurementResult?) -> Void
    ) {
        let measurement = measureUIRendering(
            name,
            category: category,
            feature: feature,
            file: file,
            function: function,
            line: line
        )

        measurement.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            let result = measurement.stop()
            completion(result)
        }
    }
}

#endif
