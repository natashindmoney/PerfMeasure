//
//  BaselineStore.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Stores baseline performance metrics for comparison
public final class BaselineStore {

    public static let shared = BaselineStore()

    private let fileManager: FileManager
    private let fileURL: URL
    private var baselines: [String: Baseline] = [:]
    private let queue = DispatchQueue(label: "com.indmoney.indprofiler.baseline", qos: .utility)
    private var isDirty = false

    // MARK: - Types

    public struct Baseline: Codable {
        public let name: String
        public let category: String
        public var sampleCount: Int
        public var totalDuration: TimeInterval
        public var minDuration: TimeInterval
        public var maxDuration: TimeInterval
        public var lastUpdated: Date
        public var totalMemoryDelta: Int64
        public var appVersion: String

        public var averageDuration: TimeInterval {
            return sampleCount > 0 ? totalDuration / Double(sampleCount) : 0
        }

        public var averageMemoryDelta: Int64 {
            return sampleCount > 0 ? totalMemoryDelta / Int64(sampleCount) : 0
        }

        init(from result: MeasurementResult) {
            self.name = result.name
            self.category = result.category
            self.sampleCount = 1
            self.totalDuration = result.metrics.duration
            self.minDuration = result.metrics.duration
            self.maxDuration = result.metrics.duration
            self.lastUpdated = Date()
            self.totalMemoryDelta = result.metrics.memoryDelta
            self.appVersion = result.context.appVersion
        }

        mutating func update(with result: MeasurementResult) {
            sampleCount += 1
            totalDuration += result.metrics.duration
            minDuration = min(minDuration, result.metrics.duration)
            maxDuration = max(maxDuration, result.metrics.duration)
            totalMemoryDelta += result.metrics.memoryDelta
            lastUpdated = Date()
            appVersion = result.context.appVersion
        }
    }

    public struct Comparison {
        public let baseline: Baseline
        public let current: MeasurementResult
        public let status: ComparisonStatus
        public let durationDeltaPercent: Double
        public let memoryDeltaPercent: Double

        public enum ComparisonStatus {
            case improvement
            case regression
            case withinExpected
        }
    }

    // MARK: - Initialization

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let perfDirectory = documentsDirectory.appendingPathComponent("INDProfilerBaselines", isDirectory: true)

        if !fileManager.fileExists(atPath: perfDirectory.path) {
            try? fileManager.createDirectory(at: perfDirectory, withIntermediateDirectories: true)
        }

        self.fileURL = perfDirectory.appendingPathComponent("baselines.json", isDirectory: false)

        loadBaselines()
        setupAutoSave()
    }

    // MARK: - Public API

    /// Records a measurement for baseline tracking
    public func record(_ result: MeasurementResult) {
        let key = baselineKey(name: result.name, category: result.category)

        queue.async { [weak self] in
            guard let self = self else { return }

            if var existing = self.baselines[key] {
                existing.update(with: result)
                self.baselines[key] = existing
            } else {
                self.baselines[key] = Baseline(from: result)
            }
            self.isDirty = true
        }
    }

    /// Compares a measurement against its baseline
    public func compare(_ result: MeasurementResult) -> Comparison? {
        let key = baselineKey(name: result.name, category: result.category)

        return queue.sync {
            guard let baseline = baselines[key] else {
                return nil
            }

            let durationDelta = ((result.metrics.duration - baseline.averageDuration) / baseline.averageDuration) * 100
            let memoryDelta: Double
            if baseline.averageMemoryDelta != 0 {
                memoryDelta = (Double(result.metrics.memoryDelta - baseline.averageMemoryDelta) / Double(abs(baseline.averageMemoryDelta))) * 100
            } else {
                memoryDelta = 0
            }

            let status: Comparison.ComparisonStatus
            if durationDelta > 20 {
                status = .regression
            } else if durationDelta < -20 {
                status = .improvement
            } else {
                status = .withinExpected
            }

            return Comparison(
                baseline: baseline,
                current: result,
                status: status,
                durationDeltaPercent: durationDelta,
                memoryDeltaPercent: memoryDelta
            )
        }
    }

    /// Returns baseline for a specific operation
    public func baseline(name: String, category: String) -> Baseline? {
        let key = baselineKey(name: name, category: category)
        return queue.sync { baselines[key] }
    }

    /// Returns all baselines
    public func allBaselines() -> [Baseline] {
        return queue.sync { Array(baselines.values) }
    }

    /// Clears baseline for a specific operation
    public func clearBaseline(name: String, category: String) {
        let key = baselineKey(name: name, category: category)
        queue.async { [weak self] in
            self?.baselines.removeValue(forKey: key)
            self?.isDirty = true
        }
    }

    /// Clears all baselines
    public func clearAll() {
        queue.async { [weak self] in
            self?.baselines.removeAll()
            self?.isDirty = true
            self?.saveBaselines()
        }
    }

    /// Forces a save of baselines to disk
    public func save() {
        queue.async { [weak self] in
            self?.saveBaselines()
        }
    }

    /// Exports baselines to a shareable data format
    public func exportData() -> Data? {
        return queue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try? encoder.encode(baselines)
        }
    }

    /// Imports baselines from data
    public func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([String: Baseline].self, from: data)

        queue.async { [weak self] in
            guard let self = self else { return }
            for (key, baseline) in imported {
                self.baselines[key] = baseline
            }
            self.isDirty = true
            self.saveBaselines()
        }
    }

    // MARK: - Private

    private func baselineKey(name: String, category: String) -> String {
        return "\(category)::\(name)"
    }

    private func loadBaselines() {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let loaded = try? decoder.decode([String: Baseline].self, from: data) {
            baselines = loaded
        }
    }

    private func saveBaselines() {
        guard isDirty else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(baselines) {
            try? data.write(to: fileURL, options: .atomic)
            isDirty = false
        }
    }

    private func setupAutoSave() {
        // Auto-save every 60 seconds if dirty
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in
            self?.saveBaselines()
        }
        timer.resume()

        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.save()
        }
        #endif
    }
}
