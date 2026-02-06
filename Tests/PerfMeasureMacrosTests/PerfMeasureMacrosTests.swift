//
//  PerfMeasureMacrosTests.swift
//  PerfMeasureMacrosTests
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(PerfMeasureMacros)
import PerfMeasureMacros

#if PERFMEASURE_ENABLE_BODY_MACROS && compiler(>=5.10)
let testMacros: [String: Macro.Type] = [
    "Measured": MeasuredMacro.self,
    "measured": MeasuredExpressionMacro.self,
    "measuredAsync": MeasuredAsyncExpressionMacro.self,
]
#else
let testMacros: [String: Macro.Type] = [
    "Measured": MeasuredUnavailableMacro.self,
    "measured": MeasuredExpressionMacro.self,
    "measuredAsync": MeasuredAsyncExpressionMacro.self,
]
#endif
#endif

final class PerfMeasureMacrosTests: XCTestCase {

    // MARK: - @Measured Macro Tests

#if PERFMEASURE_ENABLE_BODY_MACROS && compiler(>=5.10)
    func testMeasuredMacroBasic() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            @Measured("loadData")
            func loadData() -> Data {
                return fetchFromAPI()
            }
            """,
            expandedSource: """
            func loadData() -> Data {
                return PerfMeasure.shared.measure("loadData") {
                    return fetchFromAPI()
                }.value
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMeasuredMacroWithCategory() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            @Measured("parseJSON", category: "parsing")
            func parseJSON() -> Model {
                return decode(data)
            }
            """,
            expandedSource: """
            func parseJSON() -> Model {
                return PerfMeasure.shared.measure("parseJSON", category: "parsing") {
                    return decode(data)
                }.value
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMeasuredMacroWithAllArguments() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            @Measured("fetchStocks", category: "network", feature: "stocks", prNumber: "PR-123")
            func fetchStocks() -> [Stock] {
                return api.getStocks()
            }
            """,
            expandedSource: """
            func fetchStocks() -> [Stock] {
                return PerfMeasure.shared.measure("fetchStocks", category: "network", feature: "stocks", prNumber: "PR-123") {
                    return api.getStocks()
                }.value
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMeasuredMacroAsync() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            @Measured("fetchProfile", category: "network")
            func fetchProfile() async -> Profile {
                return await api.getProfile()
            }
            """,
            expandedSource: """
            func fetchProfile() async -> Profile {
                return await PerfMeasure.shared.measureAsync("fetchProfile", category: "network") {
                    return await api.getProfile()
                }.value
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMeasuredMacroAsyncThrows() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            @Measured("loadData")
            func loadData() async throws -> Data {
                return try await network.fetch()
            }
            """,
            expandedSource: """
            func loadData() async throws -> Data {
                return try await PerfMeasure.shared.measureAsync("loadData") {
                    return try await network.fetch()
                }.value
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMeasuredMacroVoidReturn() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            @Measured("processData")
            func processData() {
                doWork()
            }
            """,
            expandedSource: """
            func processData() {
                _ = PerfMeasure.shared.measure("processData") {
                    doWork()
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
#else
    func testMeasuredMacroUnavailable() throws {
        throw XCTSkip("@Measured requires Swift 5.10 or later")
    }
#endif

    // MARK: - #measured Expression Macro Tests

    func testMeasuredExpressionMacroBasic() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            let data = #measured("parseData") {
                decode(json)
            }
            """,
            expandedSource: """
            let data = PerfMeasure.shared.measure("parseData") {

                decode(json)
            } .value
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMeasuredExpressionMacroWithCategory() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            let user = #measured("parseUser", category: "parsing", feature: "auth") {
                try JSONDecoder().decode(User.self, from: data)
            }
            """,
            expandedSource: """
            let user = PerfMeasure.shared.measure("parseUser", category: "parsing", feature: "auth") {

                try JSONDecoder().decode(User.self, from: data)
            } .value
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - #measuredAsync Expression Macro Tests

    func testMeasuredAsyncExpressionMacro() throws {
        #if canImport(PerfMeasureMacros)
        assertMacroExpansion(
            """
            let profile = await #measuredAsync("fetchProfile", category: "network") {
                try await api.getProfile()
            }
            """,
            expandedSource: """
            let profile = await PerfMeasure.shared.measureAsync("fetchProfile", category: "network") {

                try await api.getProfile()
            } .value
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
