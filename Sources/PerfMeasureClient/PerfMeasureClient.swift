//
//  PerfMeasureClient.swift
//  PerfMeasureClient
//
//  Created by Natash Niranjan Bangera on 04/02/26.
//

// Re-export PerfMeasure so clients only need to import PerfMeasureClient
@_exported import PerfMeasure

// MARK: - Swift Version Compatibility
//
// | Feature                          | Swift 5.9  | Swift 6.0+ |
// |----------------------------------|------------|------------|
// | @Measured body macro             | ❌ N/A     | ✅ Available |
// | #measured expression macro       | ✅ Available | ✅ Available |
// | #measuredAsync expression macro  | ✅ Available | ✅ Available |
// | measured() helper function       | ✅ Available | ✅ Available |
// | measuredAsync() helper function  | ✅ Available | ✅ Available |
//
// For Swift 5.9 users: Use #measured/#measuredAsync macros or measured()/measuredAsync() functions.
// The @Measured body macro requires Swift 6.0+ (SE-0415: Function Body Macros).

// MARK: - Attached Macro Declaration

/// Wraps a function with automatic performance measurement.
///
/// **Requires Swift 6.0+** (SE-0415: Function Body Macros)
///
/// When applied to a function, this macro wraps the entire function body
/// with a call to `PerfMeasure.shared.measure()` or `PerfMeasure.shared.measureAsync()`.
///
/// ## Usage
///
/// Basic usage with just a name:
/// ```swift
/// @Measured("loadUserData")
/// func loadUserData() -> User {
///     // ... implementation
/// }
/// ```
///
/// With category and feature tags:
/// ```swift
/// @Measured("fetchStocks", category: "network", feature: "stocks")
/// func fetchStocks() async throws -> [Stock] {
///     // ... implementation
/// }
/// ```
///
/// With PR tracking:
/// ```swift
/// @Measured("processPayment", category: "payments", prNumber: "PR-123")
/// func processPayment(amount: Decimal) -> PaymentResult {
///     // ... implementation
/// }
/// ```
///
/// ## Parameters
/// - `name`: The name of the measurement (optional, defaults to function name)
/// - `category`: Category for grouping measurements (e.g., "network", "parsing")
/// - `feature`: Feature tag (e.g., "stocks", "payments")
/// - `prNumber`: Pull request number for tracking changes
///
/// ## Expansion
///
/// The macro expands to wrap the function body:
/// ```swift
/// // Before:
/// @Measured("loadData", category: "network")
/// func loadData() -> Data {
///     return fetchFromAPI()
/// }
///
/// // After expansion:
/// func loadData() -> Data {
///     return PerfMeasure.shared.measure("loadData", category: "network") {
///         return fetchFromAPI()
///     }.value
/// }
/// ```
///
/// For async functions, it automatically uses `measureAsync`:
/// ```swift
/// // Before:
/// @Measured("fetchProfile")
/// func fetchProfile() async throws -> Profile {
///     return try await api.getProfile()
/// }
///
/// // After expansion:
/// func fetchProfile() async throws -> Profile {
///     return try await PerfMeasure.shared.measureAsync("fetchProfile") {
///         return try await api.getProfile()
///     }.value
/// }
/// ```
///
/// ## Swift Version Requirements
///
/// - **Swift 6.0+**: `@Measured` is fully functional
/// - **Swift 5.9**: Use `#measured` / `#measuredAsync` expression macros or
///   `measured()` / `measuredAsync()` helper functions instead
///
/// - Note: Requires `PerfMeasure` from PerfMeasureClient to be imported in the file.
#if compiler(>=6.0)
@attached(body)
public macro Measured(
    _ name: String? = nil,
    category: String? = nil,
    feature: String? = nil,
    prNumber: String? = nil
) = #externalMacro(module: "PerfMeasureMacros", type: "MeasuredMacro")
#else
@attached(peer)
@available(*, unavailable, message: "@Measured requires Swift 6.0+. Use #measured/#measuredAsync or measured()/measuredAsync() instead.")
public macro Measured(
    _ name: String? = nil,
    category: String? = nil,
    feature: String? = nil,
    prNumber: String? = nil
) = #externalMacro(module: "PerfMeasureMacros", type: "MeasuredMacro")
#endif


// MARK: - Freestanding Expression Macros (Swift 5.9+)

/// Measures a synchronous expression inline.
///
/// Use this macro when you want to measure a specific expression or block of code
/// without wrapping an entire function. **Works in Swift 5.9+**.
///
/// ## Usage
///
/// ```swift
/// let user = #measured("parseUser", category: "parsing") {
///     try JSONDecoder().decode(User.self, from: jsonData)
/// }
/// ```
///
/// With feature tag:
/// ```swift
/// let stocks = #measured("filterStocks", category: "processing", feature: "stocks") {
///     allStocks.filter { $0.price > 100 }
/// }
/// ```
///
/// ## Expansion
///
/// ```swift
/// // Before:
/// let data = #measured("parseJSON") {
///     try decoder.decode(Model.self, from: json)
/// }
///
/// // After expansion:
/// let data = PerfMeasure.shared.measure("parseJSON") {
///     try decoder.decode(Model.self, from: json)
/// }.value
/// ```
///
/// - Note: Requires `PerfMeasure` from PerfMeasureClient to be imported in the file.
@freestanding(expression)
public macro measured(
    _ name: String,
    category: String? = nil,
    feature: String? = nil,
    prNumber: String? = nil
) -> Any = #externalMacro(module: "PerfMeasureMacros", type: "MeasuredExpressionMacro")


/// Measures an asynchronous expression inline.
///
/// Use this macro when you want to measure a specific async expression or block of code.
/// **Works in Swift 5.9+**.
///
/// ## Usage
///
/// ```swift
/// let profile = await #measuredAsync("fetchProfile", category: "network") {
///     try await api.getProfile()
/// }
/// ```
///
/// ## Expansion
///
/// ```swift
/// // Before:
/// let data = await #measuredAsync("fetchData") {
///     try await network.fetch(url)
/// }
///
/// // After expansion:
/// let data = await PerfMeasure.shared.measureAsync("fetchData") {
///     try await network.fetch(url)
/// }.value
/// ```
///
/// - Note: Requires `PerfMeasure` from PerfMeasureClient to be imported in the file.
@freestanding(expression)
public macro measuredAsync(
    _ name: String,
    category: String? = nil,
    feature: String? = nil,
    prNumber: String? = nil
) -> Any = #externalMacro(module: "PerfMeasureMacros", type: "MeasuredAsyncExpressionMacro")
