//
//  MeasuredMacro.swift
//  PerfMeasureMacros
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

// Body macros (@attached(body)) require Swift 6.0+ (SE-0415)
// For Swift 5.9, we provide a peer macro that emits a helpful diagnostic

#if compiler(>=6.0)

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Attached macro that wraps a function body with performance measurement.
/// Available in Swift 6.0+ only.
public struct MeasuredMacro: BodyMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {

        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction
        }

        guard let body = funcDecl.body else {
            throw MacroError.noFunctionBody
        }

        let arguments = try parseMacroArguments(from: node)
        let functionName = funcDecl.name.text
        let measurementName = arguments.name ?? functionName

        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = funcDecl.signature.effectSpecifiers?.throwsClause != nil
        let hasReturnValue = funcDecl.signature.returnClause != nil
        let measureMethod = isAsync ? "measureAsync" : "measure"

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

        let originalStatements = body.statements
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

        return args
    }
}

#else

// Swift 5.9 fallback: Provide a peer macro that emits a diagnostic
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Fallback macro for Swift versions below 6.0 that emits a helpful diagnostic.
public struct MeasuredMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let message = MeasuredUnavailableDiagnostic()
        let diagnostic = Diagnostic(node: Syntax(node), message: message)
        context.diagnose(diagnostic)
        return []
    }
}

private struct MeasuredUnavailableDiagnostic: DiagnosticMessage {
    let message: String = """
        @Measured requires Swift 6.0 or later (SE-0415: Function Body Macros).

        For Swift 5.9, use one of these alternatives instead:
        • #measured("name") { ... } - expression macro
        • #measuredAsync("name") { ... } - async expression macro
        • measured("name") { ... } - helper function
        • measuredAsync("name") { ... } - async helper function
        """
    let diagnosticID = MessageID(domain: "PerfMeasureMacros", id: "measuredUnavailable")
    let severity: DiagnosticSeverity = .error
}

#endif

// MARK: - Shared Types

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
