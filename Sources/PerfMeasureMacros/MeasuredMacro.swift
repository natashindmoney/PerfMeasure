//
//  MeasuredMacro.swift
//  PerfMeasureMacros
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Attached macro that wraps a function body with performance measurement
///
/// Usage:
/// ```swift
/// @Measured("loadData", category: "network")
/// func loadData() -> Data {
///     // function body
/// }
/// ```
///
/// Expands to:
/// ```swift
/// func loadData() -> Data {
///     return PerfMeasure.shared.measure("loadData", category: "network") {
///         // original function body
///     }.value
/// }
/// ```
public struct MeasuredMacro: BodyMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {

        // Extract the function declaration
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction
        }

        // Get the original function body
        guard let body = funcDecl.body else {
            throw MacroError.noFunctionBody
        }

        // Parse macro arguments
        let arguments = try parseMacroArguments(from: node)

        // Get function name for default measurement name
        let functionName = funcDecl.name.text
        let measurementName = arguments.name ?? functionName

        // Check if function is async
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

        // Check if function throws
        let isThrows = funcDecl.signature.effectSpecifiers?.throwsClause != nil

        // Check if function has a return type (non-Void)
        let hasReturnValue = funcDecl.signature.returnClause != nil

        // Build the measurement call
        let measureMethod = isAsync ? "measureAsync" : "measure"

        // Build arguments string
        var argsString = "\"\(measurementName)\""
        if let category = arguments.category {
            argsString += ", category: \"\(category)\""
        }
        if let feature = arguments.feature {
            argsString += ", feature: \"\(feature)\""
        }
        if let prNumber = arguments.prNumber {
            argsString += ", prNumber: \"\(prNumber)\""
        }

        // Extract original body statements
        let originalStatements = body.statements

        // Build the wrapped body
        let awaitKeyword = isAsync ? "await " : ""
        let tryKeyword = isThrows ? "try " : ""
        let valueAccess = hasReturnValue ? ".value" : ""

        let wrappedCode: CodeBlockItemListSyntax

        if hasReturnValue {
            wrappedCode = """
            return \(raw: tryKeyword)\(raw: awaitKeyword)PerfMeasure.shared.\(raw: measureMethod)(\(raw: argsString)) {
            \(originalStatements)
            }\(raw: valueAccess)
            """
        } else {
            wrappedCode = """
            _ = \(raw: tryKeyword)\(raw: awaitKeyword)PerfMeasure.shared.\(raw: measureMethod)(\(raw: argsString)) {
            \(originalStatements)
            }
            """
        }

        return Array(wrappedCode)
    }

    private static func parseMacroArguments(from node: AttributeSyntax) throws -> MacroArguments {
        var args = MacroArguments()

        guard let argumentList = node.arguments?.as(LabeledExprListSyntax.self) else {
            return args
        }

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

        return args
    }
}

// MARK: - Helper Types

private struct MacroArguments {
    var name: String?
    var category: String?
    var feature: String?
    var prNumber: String?
}

enum MacroError: Error, CustomStringConvertible {
    case notAFunction
    case noFunctionBody
    case invalidArguments

    var description: String {
        switch self {
        case .notAFunction:
            return "@Measured can only be applied to functions"
        case .noFunctionBody:
            return "@Measured requires a function with a body"
        case .invalidArguments:
            return "@Measured received invalid arguments"
        }
    }
}
