//
//  INDProfilerJSONLDestination.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

/// Destination that writes measurements to a JSONL file for later export and analysis.
///
/// Directory creation is deferred to the first write so that importing the
/// library has zero filesystem cost when JSONL logging is not used.
public final class INDProfilerJSONLDestination: INDProfilerBaseDestination {

    public static let destinationId = "jsonl"

    private let fileURL: URL
    private let fileManager: FileManager

    /// Maximum file size before rotation (default: 10MB)
    public var maxFileSize: Int = 10 * 1024 * 1024

    /// Maximum number of archived files to keep
    public var maxArchivedFiles: Int = 5

    /// Whether the directory has been created yet
    private var directoryCreated = false

    public init(
        isEnabled: Bool = true,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        // Compute the URL but do NOT create the directory yet.
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let perfDirectory = documentsDirectory.appendingPathComponent("INDProfiler", isDirectory: true)
        self.fileURL = perfDirectory.appendingPathComponent("measurements.jsonl", isDirectory: false)

        super.init(identifier: Self.destinationId, isEnabled: isEnabled, qos: .utility)
    }

    /// Returns the URL of the current measurements file
    public var currentFileURL: URL {
        return fileURL
    }

    /// Returns the directory containing all measurement files
    public var measurementsDirectory: URL {
        return fileURL.deletingLastPathComponent()
    }

    override public func performRecord(_ result: MeasurementResult) {
        ensureDirectoryExists()

        // Check file size and rotate if needed
        rotateIfNeeded()

        // Encode the result
        let dictionary = result.toDictionary()
        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]) else {
            return
        }

        // Append to file
        writeToFile(data)
    }

    // MARK: - Lazy Directory Creation

    private func ensureDirectoryExists() {
        guard !directoryCreated else { return }
        let dir = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        directoryCreated = true
    }

    private func writeToFile(_ data: Data) {
        var outputData = data
        if let newline = "\n".data(using: .utf8) {
            outputData.append(newline)
        }

        if fileManager.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                if #available(iOS 13.0, macOS 10.15.4, *) {
                    _ = try? handle.seekToEnd()
                } else {
                    handle.seekToEndOfFile()
                }
                handle.write(outputData)
            }
        } else {
            try? outputData.write(to: fileURL, options: .atomic)
        }
    }

    private func rotateIfNeeded() {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int,
              size >= maxFileSize else {
            return
        }

        // Archive current file
        let timestamp = Self._rotationFormatter.string(from: Date())
        let archiveName = "measurements_\(timestamp).jsonl"
        let archiveURL = fileURL.deletingLastPathComponent().appendingPathComponent(archiveName)

        try? fileManager.moveItem(at: fileURL, to: archiveURL)

        // Clean up old archives
        cleanupOldArchives()
    }

    /// Shared formatter for rotation timestamps — avoids creating
    /// `ISO8601DateFormatter` on every rotation.
    private static let _rotationFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    private func cleanupOldArchives() {
        let directory = fileURL.deletingLastPathComponent()
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let archives = contents
            .filter { $0.lastPathComponent.hasPrefix("measurements_") && $0.pathExtension == "jsonl" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }

        // Remove excess archives
        if archives.count > maxArchivedFiles {
            for archive in archives.suffix(from: maxArchivedFiles) {
                try? fileManager.removeItem(at: archive)
            }
        }
    }

    /// Clears all measurement files
    public func clearAll() {
        let directory = fileURL.deletingLastPathComponent()
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for file in contents where file.pathExtension == "jsonl" {
            try? fileManager.removeItem(at: file)
        }
    }

    /// Returns the current file size in bytes
    public var currentFileSize: Int {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int else {
            return 0
        }
        return size
    }
}
