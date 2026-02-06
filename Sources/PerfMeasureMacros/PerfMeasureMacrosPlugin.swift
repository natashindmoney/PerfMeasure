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
    let providingMacros: [Macro.Type] = {
        #if PERFMEASURE_ENABLE_BODY_MACROS && compiler(>=5.10)
        return [
            MeasuredMacro.self,
            MeasuredExpressionMacro.self,
            MeasuredAsyncExpressionMacro.self,
        ]
        #else
        return [
            MeasuredUnavailableMacro.self,
            MeasuredExpressionMacro.self,
            MeasuredAsyncExpressionMacro.self,
        ]
        #endif
    }()
}
