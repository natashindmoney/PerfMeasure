//
//  MeasuredExpressionMacro.swift
//  PerfMeasureMacros
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Freestanding expression macro for inline performance measurement
///
/// Usage:
/// ```swift
/// let data = #measured("parseJSON", category: "parsing") {
///     try JSONDecoder().decode(User.self, from: jsonData)
/// }
/// ```
///
/// Expands to:
/// ```swift
/// let data = PerfMeasure.shared.measure("parseJSON", category: "parsing") {
///     try JSONDecoder().decode(User.self, from: jsonData)
/// }.value
/// ```
public struct MeasuredExpressionMacro: ExpressionMacro {

    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {

        // Parse arguments
        let argumentList = node.arguments
        let arguments = try parseArguments(from: argumentList)

        // Get the trailing closure
        guard let trailingClosure = node.trailingClosure else {
            throw MeasuredExpressionError.missingClosure
        }

        // Build arguments string
        var argsString = "\"\(arguments.name)\""
        if let category = arguments.category {
            argsString += ", category: \"\(category)\""
        }
        if let feature = arguments.feature {
            argsString += ", feature: \"\(feature)\""
        }
        if let prNumber = arguments.prNumber {
            argsString += ", prNumber: \"\(prNumber)\""
        }

        // Build the expansion
        let closureBody = trailingClosure.statements

        return """
        PerfMeasure.shared.measure(\(raw: argsString)) {
        \(closureBody)
        }.value
        """
    }

    private static func parseArguments(from argumentList: LabeledExprListSyntax) throws -> ExpressionMacroArguments {
        var args = ExpressionMacroArguments(name: "")

        for argument in argumentList {
            let label = argument.label?.text

            // Extract string literal value
            guard let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                  let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
                continue
            }
            let value = segment.content.text

            switch label {
            case nil:
                // First unlabeled argument is the name
                args.name = value
            case "category":
                args.category = value
            case "feature":
                args.feature = value
            case "prNumber":
                args.prNumber = value
            default:
                break
            }
        }

        if args.name.isEmpty {
            throw MeasuredExpressionError.missingName
        }

        return args
    }
}

/// Freestanding expression macro for async inline performance measurement
///
/// Usage:
/// ```swift
/// let profile = await #measuredAsync("loadProfile", category: "network") {
///     try await api.fetchProfile()
/// }
/// ```
public struct MeasuredAsyncExpressionMacro: ExpressionMacro {

    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {

        // Parse arguments
        let argumentList = node.arguments
        let arguments = try parseArguments(from: argumentList)

        // Get the trailing closure
        guard let trailingClosure = node.trailingClosure else {
            throw MeasuredExpressionError.missingClosure
        }

        // Build arguments string
        var argsString = "\"\(arguments.name)\""
        if let category = arguments.category {
            argsString += ", category: \"\(category)\""
        }
        if let feature = arguments.feature {
            argsString += ", feature: \"\(feature)\""
        }
        if let prNumber = arguments.prNumber {
            argsString += ", prNumber: \"\(prNumber)\""
        }

        // Build the expansion
        let closureBody = trailingClosure.statements

        return """
        PerfMeasure.shared.measureAsync(\(raw: argsString)) {
        \(closureBody)
        }.value
        """
    }

    private static func parseArguments(from argumentList: LabeledExprListSyntax) throws -> ExpressionMacroArguments {
        var args = ExpressionMacroArguments(name: "")

        for argument in argumentList {
            let label = argument.label?.text

            guard let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                  let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
                continue
            }
            let value = segment.content.text

            switch label {
            case nil:
                args.name = value
            case "category":
                args.category = value
            case "feature":
                args.feature = value
            case "prNumber":
                args.prNumber = value
            default:
                break
            }
        }

        if args.name.isEmpty {
            throw MeasuredExpressionError.missingName
        }

        return args
    }
}

// MARK: - Helper Types

private struct ExpressionMacroArguments {
    var name: String
    var category: String?
    var feature: String?
    var prNumber: String?
}

enum MeasuredExpressionError: Error, CustomStringConvertible {
    case missingClosure
    case missingName

    var description: String {
        switch self {
        case .missingClosure:
            return "#measured requires a trailing closure"
        case .missingName:
            return "#measured requires a name as the first argument"
        }
    }
}
