//
//  Measured.swift
//  INDProfiler
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

// MARK: - Global Helper Functions

/// Measures a synchronous operation using INDProfiler.
///
/// When profiling is disabled via configuration, the closure runs directly
/// with only a single boolean check overhead.
///
/// - Parameters:
///   - name: Name of the operation
///   - category: Category for grouping (optional)
///   - feature: Feature tag (optional)
///   - prNumber: Pull request number (optional)
///   - operation: The operation to measure
/// - Returns: The result of the operation
@discardableResult
@inline(__always)
public func measured<T>(
    _ name: String,
    category: String? = nil,
    feature: String? = nil,
    prNumber: String? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    operation: () throws -> T
) rethrows -> T {
    return try INDProfiler.shared.measure(
        name,
        category: category,
        feature: feature,
        prNumber: prNumber,
        file: file,
        function: function,
        line: line,
        operation: operation
    ).value
}

/// Measures an asynchronous operation using INDProfiler.
///
/// When profiling is disabled via configuration, the closure runs directly
/// with only a single boolean check overhead.
///
/// - Parameters:
///   - name: Name of the operation
///   - category: Category for grouping (optional)
///   - feature: Feature tag (optional)
///   - prNumber: Pull request number (optional)
///   - operation: The async operation to measure
/// - Returns: The result of the operation
@discardableResult
@inline(__always)
public func measuredAsync<T>(
    _ name: String,
    category: String? = nil,
    feature: String? = nil,
    prNumber: String? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    operation: () async throws -> T
) async rethrows -> T {
    return try await INDProfiler.shared.measureAsync(
        name,
        category: category,
        feature: feature,
        prNumber: prNumber,
        file: file,
        function: function,
        line: line,
        operation: operation
    ).value
}
