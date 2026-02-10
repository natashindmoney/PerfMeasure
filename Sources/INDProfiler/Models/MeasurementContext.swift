//
//  MeasurementContext.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Context information for a performance measurement, including automatic and manual tags
public struct MeasurementContext: Codable, Sendable {

    // MARK: - Automatic Tags (Source Location)

    /// Source file where measurement was initiated
    public let file: String

    /// Function name where measurement was initiated
    public let function: String

    /// Line number where measurement was initiated
    public let line: Int

    // MARK: - Automatic Tags (Build Info)

    /// Build type: debug, testflight, or appstore
    public let buildType: BuildType

    /// App version string (e.g., "6.1.9")
    public let appVersion: String

    /// Build number (e.g., "1234")
    public let buildNumber: String

    // MARK: - Automatic Tags (Device Info)

    /// Device model identifier (e.g., "iPhone14,3")
    public let deviceModel: String

    /// iOS version (e.g., "17.0")
    public let osVersion: String

    // MARK: - Automatic Tags (Runtime Info)

    /// Unique session identifier for this app launch
    public let sessionId: String

    /// Timestamp when measurement started
    public let timestamp: Date

    /// Whether measurement was initiated on main thread
    public let isMainThread: Bool

    // MARK: - Manual Tags

    /// Feature name (e.g., "stocks", "payments", "kyc")
    public let feature: String?

    /// A/B experiment identifier
    public let experiment: String?

    /// Pull request number for tracking changes
    public let prNumber: String?

    /// Variant identifier for A/B testing
    public let variant: String?

    /// Custom tags for additional categorization
    public let customTags: [String: String]?

    // MARK: - Types

    public enum BuildType: String, Codable, Sendable {
        case debug
        case testflight
        case appstore

        public static var current: BuildType {
            #if DEBUG
            return .debug
            #else
            if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
                return .testflight
            }
            return .appstore
            #endif
        }
    }

    // MARK: - Initialization

    public init(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        feature: String? = nil,
        experiment: String? = nil,
        prNumber: String? = nil,
        variant: String? = nil,
        customTags: [String: String]? = nil
    ) {
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.buildType = BuildType.current
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.deviceModel = Self.deviceModelIdentifier
        #if canImport(UIKit)
        self.osVersion = UIDevice.current.systemVersion
        #else
        self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        self.sessionId = Self.currentSessionId
        self.timestamp = Date()
        self.isMainThread = Thread.isMainThread
        self.feature = feature
        self.experiment = experiment
        self.prNumber = prNumber
        self.variant = variant
        self.customTags = customTags
    }

    // MARK: - Static Properties

    private static let currentSessionId: String = UUID().uuidString

    private static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    // MARK: - Dictionary Conversion

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "file": file,
            "function": function,
            "line": line,
            "build_type": buildType.rawValue,
            "app_version": appVersion,
            "build_number": buildNumber,
            "device_model": deviceModel,
            "os_version": osVersion,
            "session_id": sessionId,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "is_main_thread": isMainThread
        ]

        if let feature = feature {
            dict["feature"] = feature
        }
        if let experiment = experiment {
            dict["experiment"] = experiment
        }
        if let prNumber = prNumber {
            dict["pr_number"] = prNumber
        }
        if let variant = variant {
            dict["variant"] = variant
        }
        if let customTags = customTags {
            dict["custom_tags"] = customTags
        }

        return dict
    }
}
