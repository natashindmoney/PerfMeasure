//
//  PerfMeasureMacrosPlugin.swift
//  PerfMeasureMacros
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PerfMeasureMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MeasuredMacro.self,
        MeasuredExpressionMacro.self,
        MeasuredAsyncExpressionMacro.self,
    ]
}
