//
//  Measured.swift
//  INDCommon
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import Foundation

// MARK: - Global Helper Functions

/// Measures a synchronous operation using PerfMeasure
/// - Parameters:
///   - name: Name of the operation
///   - category: Category for grouping (optional)
///   - feature: Feature tag (optional)
///   - operation: The operation to measure
/// - Returns: The result of the operation
@discardableResult
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
    return try PerfMeasure.shared.measure(
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

/// Measures an asynchronous operation using PerfMeasure
/// - Parameters:
///   - name: Name of the operation
///   - category: Category for grouping (optional)
///   - feature: Feature tag (optional)
///   - operation: The async operation to measure
/// - Returns: The result of the operation
@discardableResult
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
    return try await PerfMeasure.shared.measureAsync(
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

/// Measures a synchronous operation and returns both value and measurement
/// - Parameters:
///   - name: Name of the operation
///   - category: Category for grouping (optional)
///   - feature: Feature tag (optional)
///   - operation: The operation to measure
/// - Returns: MeasuredValue containing the result and measurement
@discardableResult
public func measuredWithResult<T>(
    _ name: String,
    category: String? = nil,
    feature: String? = nil,
    prNumber: String? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    operation: () throws -> T
) rethrows -> MeasuredValue<T> {
    return try PerfMeasure.shared.measure(
        name,
        category: category,
        feature: feature,
        prNumber: prNumber,
        file: file,
        function: function,
        line: line,
        operation: operation
    )
}

/// Measures an asynchronous operation and returns both value and measurement
/// - Parameters:
///   - name: Name of the operation
///   - category: Category for grouping (optional)
///   - feature: Feature tag (optional)
///   - operation: The async operation to measure
/// - Returns: MeasuredAsyncValue containing the result and measurement
@discardableResult
public func measuredAsyncWithResult<T>(
    _ name: String,
    category: String? = nil,
    feature: String? = nil,
    prNumber: String? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    operation: () async throws -> T
) async rethrows -> MeasuredAsyncValue<T> {
    return try await PerfMeasure.shared.measureAsync(
        name,
        category: category,
        feature: feature,
        prNumber: prNumber,
        file: file,
        function: function,
        line: line,
        operation: operation
    )
}
