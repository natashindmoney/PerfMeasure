//
//  INDProfilerExportManager.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Manages export of performance measurement data
public final class INDProfilerExportManager {

    public static let shared = INDProfilerExportManager()

    private let fileManager: FileManager

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Export Methods

    /// Creates an export bundle containing all performance data
    public func createExportBundle() -> ExportBundle? {
        let measurements = getMeasurementsFileURL()
        let baselines = getBaselinesFileURL()

        guard measurements != nil || baselines != nil else {
            return nil
        }

        return ExportBundle(
            measurementsURL: measurements,
            baselinesURL: baselines,
            metadata: createMetadata()
        )
    }

    /// Exports all performance data to a temporary directory and returns the URL
    public func exportToTemporaryDirectory() -> URL? {
        guard let bundle = createExportBundle() else {
            return nil
        }

        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("INDProfilerExport_\(Date().timeIntervalSince1970)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Copy measurements
            if let measurementsURL = bundle.measurementsURL {
                let destURL = tempDir.appendingPathComponent("measurements.jsonl")
                try fileManager.copyItem(at: measurementsURL, to: destURL)
            }

            // Copy baselines
            if let baselinesURL = bundle.baselinesURL {
                let destURL = tempDir.appendingPathComponent("baselines.json")
                try fileManager.copyItem(at: baselinesURL, to: destURL)
            }

            // Write metadata
            let metadataURL = tempDir.appendingPathComponent("metadata.json")
            let metadataData = try JSONEncoder().encode(bundle.metadata)
            try metadataData.write(to: metadataURL)

            return tempDir
        } catch {
            return nil
        }
    }

    /// Creates a shareable archive (ZIP) of performance data
    public func createShareableArchive() -> URL? {
        guard let exportDir = exportToTemporaryDirectory() else {
            return nil
        }

        let archiveURL = fileManager.temporaryDirectory
            .appendingPathComponent("INDProfiler_\(formattedTimestamp()).zip")

        // Remove existing archive if present
        try? fileManager.removeItem(at: archiveURL)

        do {
            let coordinator = NSFileCoordinator()
            var error: NSError?

            coordinator.coordinate(
                readingItemAt: exportDir,
                options: [.forUploading],
                error: &error
            ) { zipURL in
                try? fileManager.copyItem(at: zipURL, to: archiveURL)
            }

            if error != nil {
                return nil
            }

            // Clean up export directory
            try? fileManager.removeItem(at: exportDir)

            return archiveURL
        }
    }

    #if canImport(UIKit)
    /// Presents a share sheet for the performance data
    public func presentShareSheet(from viewController: UIViewController) {
        guard let archiveURL = createShareableArchive() else {
            return
        }

        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(
                activityItems: [archiveURL],
                applicationActivities: nil
            )

            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }

            viewController.present(activityVC, animated: true)
        }
    }
    #endif

    // MARK: - Helper Methods

    private func getMeasurementsFileURL() -> URL? {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let fileURL = documentsDir
            .appendingPathComponent("INDProfiler", isDirectory: true)
            .appendingPathComponent("measurements.jsonl")

        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    private func getBaselinesFileURL() -> URL? {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let fileURL = documentsDir
            .appendingPathComponent("INDProfilerBaselines", isDirectory: true)
            .appendingPathComponent("baselines.json")

        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    private func createMetadata() -> ExportMetadata {
        return ExportMetadata(
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            deviceModel: Self._deviceModel,
            osVersion: Self._osVersion
        )
    }

    // MARK: - Cached Device Info (avoids Mirror on every export)

    private static let _deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let data = Data(bytes: &systemInfo.machine,
                        count: Int(_SYS_NAMELEN))
        let length = data.firstIndex(of: 0) ?? data.count
        return String(decoding: data[..<length], as: UTF8.self)
    }()

    private static let _osVersion: String = {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }()

    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    // MARK: - Types

    public struct ExportBundle {
        public let measurementsURL: URL?
        public let baselinesURL: URL?
        public let metadata: ExportMetadata
    }

    public struct ExportMetadata: Codable {
        public let exportDate: Date
        public let appVersion: String
        public let buildNumber: String
        public let deviceModel: String
        public let osVersion: String
    }
}
