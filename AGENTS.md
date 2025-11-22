# Project Instructions for AI Coding Agents

**Last updated:** 2025-11-22 19:15

<!-- {mission} -->

## Mission Statement

**aranetctl** is a Swift command-line tool for interacting with Aranet4, Aranet2, Aranet Radiation, and Aranet Radon Plus Bluetooth sensors. The project provides a modern Swift reimplementation of the Python-based aranet4 library, offering native performance and type safety for reading sensor data, fetching historical logs, and managing device settings.

Key features:

- Read current sensor measurements (CO2, temperature, humidity, pressure)
- Fetch and export historical data logs
- Configure device settings (update intervals, integrations, Bluetooth range)
- Scan for nearby Aranet devices
- Native Bluetooth LE communication

## Technology Stack

- **Language:** Swift 6.2+
- **Framework:** Swift Argument Parser (CLI), CoreBluetooth (Bluetooth LE)
- **Version Control:** Git
- **Package Manager:** Swift Package Manager (SPM)
- **License:** MIT (inherited from python-impl)

<!-- {principles} -->

## Primary Instructions

- Avoid making assumptions. If you need additional context to accurately answer the user, ask the user for the missing information. Be specific about which context you need.
- Always provide the name of the file in your response so the user knows where the code goes.
- Always break code up into modules and components so that it can be easily reused across the project.
- All code you write MUST be fully optimized. ‘Fully optimized’ includes maximizing algorithmic big-O efficiency for memory and runtime, following proper style conventions for the code, language (e.g. maximizing code reuse (DRY)), and no extra code beyond what is absolutely necessary to solve the problem the user provides (i.e. no technical debt). If the code is not fully optimized, you will be fined $100.

### Working Together

This file (`AGENTS.md`) is the primary instructions file for AI coding assistants working on this project. Agent-specific instruction files (such as `.github/copilot-instructions.md`, `CLAUDE.md`) reference this document, maintaining a single source of truth.

When initializing a session or analyzing the workspace, refer to instruction files in this order:

1. `AGENTS.md` (this file - primary instructions and single source of truth)
2. Agent-specific reference file (if present - points back to AGENTS.md)

### Update Protocol (CRITICAL)

**PROACTIVELY update this file (`AGENTS.md`) as we work together.** Whenever you make a decision, choose a technology, establish a convention, or define a standard, you MUST update AGENTS.md immediately in the same response.

**Update ONLY this file (`AGENTS.md`)** when coding standards, conventions, or project decisions evolve. Do not modify agent-specific reference files unless the reference mechanism itself needs changes.

**When to update** (do this automatically, without being asked):

- Technology choices (build tools, languages, frameworks)
- Directory structure decisions
- Coding conventions and style guidelines
- Architecture decisions
- Naming conventions
- Build/test/deployment procedures

**How to update AGENTS.md:**

- Maintain the "Last updated" timestamp at the top
- Add content to the relevant section (Project Overview, Coding Standards, etc.)
- Add entries to the "Recent Updates & Decisions" log at the bottom with:
  - Date (with time if multiple updates per day)
  - Brief description
  - Reasoning for the change
- Preserve this structure: title header → timestamp → main instructions → "Recent Updates & Decisions" section

## Best Practices

### When Updating This Repository

1. **Maintain Consistency**: Keep code style consistent across the codebase
2. **Test First**: Write tests before implementing features when applicable
3. **Document Changes**: Update documentation when changing functionality
4. **Code Review**: [Describe your code review process]
5. **Date Changes**: Update the "Last updated" timestamp in this file when making changes
6. **Log Updates**: Add entries to "Recent Updates & Decisions" section below

### Development Guidelines

[Add project-specific development guidelines]

- [Guideline 1]
- [Guideline 2]
- [Guideline 3]

### Security & Safety

- Never include API keys, tokens, or credentials in code
- Always require explicit human confirmation before commits
- Maintain conventional commit message standards
- Keep change history transparent through commit messages
- [Add project-specific security guidelines]

### Testing

[Describe your testing approach]

- Unit tests: [location and conventions]
- Integration tests: [location and conventions]
- Test coverage requirements: [if any]
- Testing framework: [e.g., Jest, pytest, JUnit]

### Documentation

[Describe your documentation requirements]

- Code comments: [when and how]
- API documentation: [format and location]
- README updates: [when required]
- Changelog: [if maintained]

<!-- {languages} -->

# Swift Coding Conventions for DoomKit

*Last updated: November 16, 2025*

This document establishes comprehensive coding standards and style guidelines for the DoomKit Swift Package. These conventions ensure consistency, maintainability, and adherence to Swift best practices across the entire codebase.

---

## Table of Contents

1. [File Organization](#file-organization)
2. [Naming Conventions](#naming-conventions)
3. [Code Structure](#code-structure)
4. [Access Control](#access-control)
5. [Type Declarations](#type-declarations)
6. [Property Declarations](#property-declarations)
7. [Function Declarations](#function-declarations)
8. [Control Flow](#control-flow)
9. [Error Handling](#error-handling)
10. [Concurrency & Async/Await](#concurrency--asyncawait)
11. [Protocols & Extensions](#protocols--extensions)
12. [Generics](#generics)
13. [Comments & Documentation](#comments--documentation)
14. [Formatting & Whitespace](#formatting--whitespace)
15. [Swift-Specific Patterns](#swift-specific-patterns)
16. [Package-Specific Conventions](#package-specific-conventions)

---

## File Organization

### Import Statements

```swift
// CORRECT: Organize imports alphabetically, Foundation first if needed
import Foundation
import CoreLocation
import MapKit
import WeatherKit

// INCORRECT: Random order
import WeatherKit
import Foundation
import CoreLocation
```

### File Structure Order

1. Import statements
2. Type declarations (class, struct, enum, protocol)
3. Properties (in order: static, instance)
4. Initializers
5. Lifecycle methods
6. Public methods
7. Internal methods
8. Private methods
9. Nested types (if applicable)

### Single Responsibility

- **One primary type per file** (exceptions for small, tightly-coupled helper types)
- File name must match the primary type name: `ProcessManager.swift` contains `ProcessManager` class
- Place closely related types in the same file only when they form a cohesive unit

---

## Naming Conventions

### General Rules

- Use clear, descriptive names that convey intent
- Prefer full words over abbreviations
- Use American English spelling

### Types (Classes, Structs, Enums, Protocols)

```swift
// CORRECT: PascalCase for types
public class ProcessManager { }
public struct Location { }
public enum ProcessQuality { }
public protocol ProcessController { }

// INCORRECT
public class processManager { }  // Wrong case
public struct location { }       // Wrong case
```

### Properties & Variables

```swift
// CORRECT: camelCase for properties and variables
let locationManager = LocationManager()
var subscriptions: [ProcessSubscription] = []
private let updateInterval: TimeInterval = 60

// INCORRECT
let LocationManager = LocationManager()  // Wrong case
var Subscriptions: [ProcessSubscription] = []  // Wrong case
```

### Functions & Methods

```swift
// CORRECT: camelCase, descriptive action verbs
func refreshData(for location: Location) async throws -> ProcessSensor?
func updateLocation(location: Location) -> Void
private func significantLocationChange(previous: Location?, current: Location) -> Bool

// INCORRECT
func RefreshData() { }  // Wrong case
func upd() { }  // Too abbreviated
func location_update() { }  // Snake case
```

### Constants

```swift
// CORRECT: Use static let for type-level constants
public class LocationManager {
    public static let houseOfWorldCultures = Location(latitude: 52.51889, longitude: 13.36528)
}

// CORRECT: camelCase for constant properties
private let updateInterval: TimeInterval = 60
```

### Enums

```swift
// CORRECT: PascalCase for enum name, camelCase for cases
public enum ProcessQuality {
    case good
    case uncertain
    case bad
    case unknown
}

// CORRECT: Associated value enums
public enum ProcessSelector: Hashable {
    case weather(Weather)
    case forecast(Forecast)
    case covid(Covid)
}
```

### Protocols

```swift
// CORRECT: Use descriptive protocol names
public protocol ProcessController { }
public protocol LocationManagerDelegate: Identifiable where ID == UUID { }

// CORRECT: Protocol names ending in -able, -ible indicate capability
protocol Sendable { }  // Standard library example
```

---

## Code Structure

### Braces

```swift
// CORRECT: Opening brace on same line, closing brace on new line
public class ProcessManager {
    func updateSubscriptions() {
        for subscription in subscriptions {
            subscription.update(timeout: updateInterval)
        }
    }
}

// INCORRECT
public class ProcessManager
{  // Opening brace on new line
    func updateSubscriptions()
    {
        for subscription in subscriptions {
            subscription.update(timeout: updateInterval) }  // Closing brace on same line
    }
}
```

### Indentation

- Use **4 spaces** for indentation (no tabs)
- Align continuation lines with the opening delimiter

```swift
// CORRECT: 4-space indentation
public init(
    name: String, location: Location, placemark: String?, customData: [String: Any]?,
    measurements: [ProcessSelector: [ProcessValue<Dimension>]], timestamp: Date?
) {
    self.name = name
    self.location = location
    self.placemark = placemark
    self.customData = customData
    self.measurements = measurements
    self.timestamp = timestamp
}
```

### Line Length

- Target maximum: **120 characters** per line
- Break long lines at logical points (parameters, operators, closures)

```swift
// CORRECT: Break long function signatures
public func dataWithRetry(
    from url: URL, retryCount: Int = 3, retryInterval: TimeInterval = 1.0,
    delegate: (any URLSessionTaskDelegate)? = nil
) async throws -> (Data, URLResponse) {
    // Implementation
}
```

---

## Access Control

### Access Levels (Most to Least Restrictive)

1. `private` - Only visible within the current declaration
2. `fileprivate` - Visible within the same source file
3. `internal` - Visible within the module (default)
4. `public` - Visible to consumers of the module
5. `open` - Visible and subclassable outside the module

### Package Guidelines

```swift
// CORRECT: Explicit public for exported API
public class ProcessManager: Identifiable, LocationManagerDelegate {
    public let id = UUID()
    public static let shared = ProcessManager()

    private let locationManager = LocationManager()  // Internal implementation
    private var location: Location?  // Private state

    public func refreshSubscriptions() {  // Public API
        // Implementation
    }

    private func updateSubscriptions() {  // Private helper
        // Implementation
    }
}
```

### Rules

- **Always explicit**: Mark APIs as `public` explicitly; avoid relying on default `internal`
- **Minimize exposure**: Only expose what consumers need
- **Private by default**: Start with `private`, increase visibility as needed
- **No `open` classes**: Package doesn't require subclassing from consumers

---

## Type Declarations

### Classes

```swift
// CORRECT: Class with protocol conformance
public class ProcessManager: Identifiable, LocationManagerDelegate {
    public let id = UUID()
    public static let shared = ProcessManager()

    private init() {
        // Singleton pattern
    }
}

// CORRECT: Subclass with inheritance
public class WeatherController: ProcessController {
    public func refreshData(for location: Location) async throws -> ProcessSensor? {
        // Implementation
    }
}
```

### Structs

```swift
// CORRECT: Simple value type
public struct Location: Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// CORRECT: Generic struct with computed properties
public struct ProcessValue<T: Dimension>: Identifiable {
    public let id = UUID()
    public let value: Measurement<T>
    public let quality: ProcessQuality
    public let timestamp: Date
}
```

### Enums

```swift
// CORRECT: Simple enum
public enum ProcessQuality {
    case good
    case uncertain
    case bad
    case unknown
}

// CORRECT: Enum with raw values
public enum Weather: Int, CaseIterable {
    case temperature = 0
    case apparentTemperature = 1
    case dewPoint = 2
}

// CORRECT: Enum with associated values
public enum ProcessSelector: Hashable {
    case weather(Weather)
    case forecast(Forecast)
    case covid(Covid)
}
```

### Protocols

```swift
// CORRECT: Protocol with associated type constraints
public protocol LocationManagerDelegate: Identifiable where ID == UUID {
    func locationManager(didUpdateLocation location: Location) -> Void
}

// CORRECT: Simple protocol
public protocol ProcessController {
    func refreshData(for location: Location) async throws -> ProcessSensor?
}
```

---

## Property Declarations

### Stored Properties

```swift
// CORRECT: Property declarations with explicit types
public class ProcessManager {
    public let id = UUID()  // Type inferred from initializer
    private let locationManager = LocationManager()
    private var location: Location?  // Optional type explicit
    private let updateInterval: TimeInterval = 60  // Explicit type
    private var subscriptions: [ProcessSubscription] = []  // Explicit initialization
}
```

### Computed Properties

```swift
// CORRECT: Computed property
public struct Location {
    public let latitude: Double
    public let longitude: Double

    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}

// CORRECT: Read-only computed property (implicit get)
var isReady: Bool {
    return location != nil && subscriptions.isEmpty == false
}
```

### Property Observers

```swift
// CORRECT: willSet and didSet
var location: Location? {
    willSet {
        print("About to set location to \(newValue)")
    }
    didSet {
        if location != oldValue {
            refreshSubscriptions()
        }
    }
}
```

### Lazy Properties

```swift
// CORRECT: Lazy initialization for expensive resources
lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()
```

---

## Function Declarations

### Basic Structure

```swift
// CORRECT: Function signature formatting
public func refreshData(for location: Location) async throws -> ProcessSensor? {
    var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
    // Implementation
    return ProcessSensor(name: "", location: location, measurements: measurements, timestamp: Date.now)
}
```

### Parameter Labels

```swift
// CORRECT: Descriptive external labels
func updateLocation(location: Location) -> Void { }
func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) { }

// CORRECT: Omit external label with underscore when appropriate
func process(_ data: Data) -> Result { }

// INCORRECT: Redundant labels
func updateLocation(location location: Location) -> Void { }  // Redundant
```

### Default Parameters

```swift
// CORRECT: Default parameters at end
public func dataWithRetry(
    from url: URL,
    retryCount: Int = 3,
    retryInterval: TimeInterval = 1.0,
    delegate: (any URLSessionTaskDelegate)? = nil
) async throws -> (Data, URLResponse) {
    // Implementation
}
```

### Multiple Initializers

```swift
// CORRECT: Convenience initializers calling designated initializers
public struct ProcessValue<T: Dimension> {
    // Designated initializer (most comprehensive)
    public init(value: Measurement<T>, customData: [String: Any]?, quality: ProcessQuality, timestamp: Date) {
        self.value = value
        self.customData = customData
        self.quality = quality
        self.timestamp = timestamp
    }

    // Convenience initializers
    public init(value: Measurement<T>, quality: ProcessQuality, timestamp: Date) {
        self.init(value: value, customData: nil, quality: quality, timestamp: timestamp)
    }

    public init(value: Measurement<T>, quality: ProcessQuality) {
        self.init(value: value, quality: quality, timestamp: Date.now)
    }

    public init(value: Measurement<T>) {
        self.init(value: value, quality: .unknown)
    }
}
```

### Return Type Void

```swift
// CORRECT: Explicit Void return type
public func updateLocation(location: Location) -> Void {
    // Implementation
}

// ALSO CORRECT: Omit return type for Void
public func updateLocation(location: Location) {
    // Implementation
}
```

---

## Control Flow

### Boolean Comparisons

**ALWAYS use explicit comparisons with boolean values.**

```swift
// CORRECT: Explicit boolean comparisons
if verbose == true {
    print("Debug mode enabled")
}

if isEnabled == false {
    return
}

while isRunning == true {
    process()
}

// INCORRECT: Implicit boolean checks
if verbose {  // Wrong - not explicit
    print("Debug mode enabled")
}

if !isEnabled {  // Wrong - not explicit
    return
}

while isRunning {  // Wrong - not explicit
    process()
}
```

### If Statements

```swift
// CORRECT: Standard if statement
if location != nil {
    refreshSubscriptions()
}

// CORRECT: If-let for optional binding
if let location = self.location {
    delegate.locationManager(didUpdateLocation: location)
}

// CORRECT: Guard for early return
guard let location = self.location else {
    return
}

// CORRECT: Multiple conditions with explicit boolean check
if needsUpdate == true {
    self.location = location
    if let delegate = self.delegate {
        delegate.locationManager(didUpdateLocation: location)
    }
}
```

### Guard Statements

```swift
// CORRECT: Guard for preconditions and early exits
guard ReachabilityManager.shared.isConnected else {
    throw URLError(.notConnectedToInternet)
}

guard let url = URL(string: "https://api.example.com/data") else {
    return nil
}

// CORRECT: Single guard statements (preferred)
guard let data = data else {
    throw NetworkError.invalidResponse
}

guard let response = response as? HTTPURLResponse else {
    throw NetworkError.invalidResponse
}

guard (200...299).contains(response.statusCode) else {
    throw NetworkError.invalidResponse
}

// AVOID: Multiple guard conditions
guard let data = data,
      let response = response as? HTTPURLResponse,
      (200...299).contains(response.statusCode) else {
    throw NetworkError.invalidResponse
}
```

### For Loops

```swift
// CORRECT: For-in loops
for subscription in subscriptions {
    subscription.update(timeout: updateInterval)
}

// CORRECT: Enumeration with index
for (index, item) in items.enumerated() {
    print("\(index): \(item)")
}

// CORRECT: Filtering in loop
for subscription in subscriptions where subscription.isPending() {
    subscription.reset()
}
```

### Switch Statements

```swift
// CORRECT: Exhaustive switch on enum
switch quality {
    case .good:
        return "✓"
    case .uncertain:
        return "~"
    case .bad:
        return "✗"
    case .unknown:
        return "?"
}

// CORRECT: Switch with multiple cases
switch connectionType {
    case .wifi, .ethernet:
        return true
    case .cellular:
        return false
    case .unknown:
        return false
}
```

### Ternary Operator

```swift
// CORRECT: Simple conditions
let result = condition ? trueValue : falseValue

// AVOID: Nested ternary (use if-else instead)
let result = condition1 ? value1 : (condition2 ? value2 : value3)  // Hard to read
```

---

## Error Handling

### Error Definitions

```swift
// CORRECT: Custom error enum
enum NetworkError: Error {
    case invalidResponse
    case serverError(statusCode: Int)
    case noData
}
```

### Throwing Functions

```swift
// CORRECT: Function that can throw
public func refreshData(for location: Location) async throws -> ProcessSensor? {
    let weather = try await WeatherService.shared.weather(for: clLocation)
    // Process weather data
    return sensor
}
```

### Try-Catch Blocks

```swift
// CORRECT: Standard try-catch
do {
    let (data, response) = try await self.data(from: url, delegate: delegate)
    return (data, response)
} catch {
    lastError = error
    if attempt < retryCount - 1 {
        try await Task.sleep(nanoseconds: UInt64(retryInterval * 1_000_000_000))
        continue
    }
}

// CORRECT: Specific error catching
do {
    let result = try riskyOperation()
    return result
} catch NetworkError.invalidResponse {
    print("Invalid response")
    return nil
} catch {
    print("Unknown error: \(error)")
    return nil
}
```

### Optional Try

```swift
// CORRECT: try? for optional result
if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
    // Use placemark
}

// CORRECT: try! only when failure is impossible
let config = try! Configuration.load()  // Only if guaranteed to succeed
```

---

## Concurrency & Async/Await

### Async Functions

```swift
// CORRECT: Async function declaration
public func refreshData(for location: Location) async throws -> ProcessSensor? {
    let weather = try await WeatherService.shared.weather(for: clLocation)
    let placemark = await LocationManager.reverseGeocodeLocation(location: location)
    return ProcessSensor(/* ... */)
}
```

### Task Creation

```swift
// CORRECT: Create task for async work
Task {
    await delegate.refreshData(location: location)
}

// CORRECT: Task with error handling
Task {
    do {
        let result = try await fetchData()
        process(result)
    } catch {
        print("Error: \(error)")
    }
}
```

### Actor Usage

```swift
// CORRECT: Actor for thread-safe state management
actor NetworkManager {
    private var isConnected = true

    func updateConnectionStatus(_ status: Bool) {
        self.isConnected = status
    }

    func checkConnection() -> Bool {
        return isConnected
    }
}
```

### Sendable Conformance

```swift
// CORRECT: @unchecked Sendable for custom Dimension types
public class UnitRadiation: Dimension, @unchecked Sendable {
    public static let sieverts = UnitRadiation(
        symbol: "Sv/h",
        converter: UnitConverterLinear(coefficient: 1.0)
    )
}
```

### Async Sequences

```swift
// CORRECT: Iterating async sequence
for await value in asyncSequence {
    process(value)
}
```

---

## Protocols & Extensions

### Protocol Declarations

```swift
// CORRECT: Protocol with requirements
public protocol ProcessController {
    func refreshData(for location: Location) async throws -> ProcessSensor?
}

// CORRECT: Protocol with associated type constraints
public protocol LocationManagerDelegate: Identifiable where ID == UUID {
    func locationManager(didUpdateLocation location: Location) -> Void
}
```

### Protocol Conformance

```swift
// CORRECT: Conformance in type definition
public class ProcessManager: Identifiable, LocationManagerDelegate {
    // Implementation
}

// CORRECT: Conformance in extension (when appropriate)
extension ProcessManager: CustomStringConvertible {
    public var description: String {
        return "ProcessManager with \(subscriptions.count) subscriptions"
    }
}
```

### Extensions

```swift
// CORRECT: Extension to add functionality
extension URLSession {
    public func dataWithRetry(
        from url: URL, retryCount: Int = 3, retryInterval: TimeInterval = 1.0
    ) async throws -> (Data, URLResponse) {
        // Implementation
    }
}

// CORRECT: Extension for protocol conformance
extension Location: Equatable, Hashable {
    // Compiler synthesizes conformance for structs with Equatable/Hashable properties
}
```

### Extension Organization

```swift
// CORRECT: Organize extensions by purpose
// File: ProcessManager.swift

public class ProcessManager {
    // Core implementation
}

// MARK: - LocationManagerDelegate
extension ProcessManager: LocationManagerDelegate {
    public func locationManager(didUpdateLocation location: Location) {
        // Implementation
    }
}

// MARK: - Subscription Management
extension ProcessManager {
    public func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) {
        // Implementation
    }
}
```

---

## Generics

### Generic Types

```swift
// CORRECT: Generic struct with type constraints
public struct ProcessValue<T: Dimension>: Identifiable {
    public let id = UUID()
    public let value: Measurement<T>
    public let quality: ProcessQuality
}
```

### Generic Functions

```swift
// CORRECT: Generic function with constraints
func measure<T: Dimension>(_ value: Double, unit: T) -> Measurement<T> {
    return Measurement(value: value, unit: unit)
}
```

### Associated Types

```swift
// CORRECT: Protocol with associated type
protocol Container {
    associatedtype Item
    var items: [Item] { get set }
    mutating func add(_ item: Item)
}
```

### Type Erasure

```swift
// CORRECT: Using 'any' for existential types
private var subscribers: [UUID: any ProcessSubscriber] = [:]

public func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) {
    subscribers[subscriber.id] = subscriber
}
```

---

## Comments & Documentation

### Single-Line Comments

```swift
// CORRECT: Comment explains why, not what
// Check if device is connected before attempting network request
guard ReachabilityManager.shared.isConnected else {
    throw URLError(.notConnectedToInternet)
}

// INCORRECT: States the obvious
// Set location to new location
self.location = location
```

### Multi-Line Comments

```swift
// CORRECT: Use single-line style for multi-line comments
// This function performs exponential backoff retry logic
// for network requests. It checks connectivity before each
// attempt and throws immediately if connection is lost.
```

### Documentation Comments

```swift
// CORRECT: DocC-style documentation
/// A simple and fast logging facility with support for different log levels and detailed timestamps.
public class Trace {
    /// Represents different log levels
    public enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
    }

    /// Creates a new Logger instance
    /// - Parameters:
    ///   - minimumLevel: Minimum level of logs to display
    ///   - showColors: Whether to use ANSI colors in console output
    ///   - dateFormat: Format string for timestamps (default: "yyyy-MM-dd HH:mm:ss.SSS")
    ///   - logFile: Path to file for writing logs (optional)
    public init(
        minimumLevel: Level = .debug,
        showColors: Bool = true,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSS",
        logFile: String? = nil
    ) {
        // Implementation
    }
}
```

### MARK Comments

```swift
// CORRECT: Use MARK to organize code sections
public class WeatherController {
    // MARK: - Properties
    private let service = WeatherService.shared

    // MARK: - Initialization
    public init() { }

    // MARK: - Public Methods
    public func refreshData(for location: Location) async throws -> ProcessSensor? {
        // Implementation
    }

    // MARK: - Private Helpers
    private func processWeatherData(_ data: WeatherData) -> ProcessSensor {
        // Implementation
    }
}
```

### TODO/FIXME Comments

```swift
// TODO: Implement caching mechanism for weather data
// FIXME: Handle edge case when location is exactly on boundary
// NOTE: This assumes the API always returns valid data
```

---

## Formatting & Whitespace

### Blank Lines

```swift
// CORRECT: Blank line between logical sections
public class ProcessManager {
    public let id = UUID()
    public static let shared = ProcessManager()

    private let locationManager = LocationManager()
    private var location: Location?

    private init() {
        self.locationManager.delegate = self
    }

    public func refreshSubscriptions() {
        // Implementation
    }
}
```

### Spacing

```swift
// CORRECT: Space after comma, around operators
let values = [1, 2, 3, 4]
let sum = a + b
let range = 0.0 ... 100.0

// CORRECT: No space around range operators
for i in 0..<count { }
let range = 0...10

// CORRECT: No space before colon, space after
var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) { }

// INCORRECT
let values=[1,2,3,4]  // Missing spaces
let sum=a+b  // Missing spaces
var dict : [String : Int]  // Spaces before colons
```

### Trailing Whitespace

```swift
// AVOID: Trailing whitespace at end of lines
func process() {
    let value = 10___
}  // Remove trailing spaces

// CORRECT: No trailing whitespace
func process() {
    let value = 10
}
```

### Empty Lines at File End

```swift
// CORRECT: Single empty line at end of file
public class ProcessManager {
    // Implementation
}

// ← One blank line here, then EOF
```

---

## Swift-Specific Patterns

### Optionals

```swift
// CORRECT: Optional binding with if-let
if let location = self.location {
    process(location)
}

// CORRECT: Optional binding with guard
guard let location = self.location else {
    return
}

// CORRECT: Optional chaining
let count = subscribers[id]?.subscriptions.count

// CORRECT: Nil coalescing
let value = optionalValue ?? defaultValue

// AVOID: Force unwrapping (use only when absolutely certain)
let value = optionalValue!  // Only if guaranteed non-nil
```

### Type Inference

```swift
// CORRECT: Let Swift infer obvious types
let manager = ProcessManager.shared
let id = UUID()
let values = [1, 2, 3]

// CORRECT: Explicit types for clarity
let timeout: TimeInterval = 60
let measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]

// AVOID: Redundant type annotations
let manager: ProcessManager = ProcessManager.shared  // Type obvious
```

### Closures

```swift
// CORRECT: Trailing closure syntax
Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
    self.updateSubscriptions()
}

// CORRECT: Explicit closure parameters
items.map { item in
    return item.value * 2
}

// CORRECT: Shorthand when simple
items.map { $0.value * 2 }

// CORRECT: Multiple trailing closures (Swift 5.3+)
UIView.animate(withDuration: 0.3) {
    view.alpha = 0
} completion: { _ in
    view.removeFromSuperview()
}
```

### Collections

```swift
// CORRECT: Array initialization
var subscriptions: [ProcessSubscription] = []
let values = [1, 2, 3, 4, 5]

// CORRECT: Dictionary initialization
var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
let dict = ["key": "value"]

// CORRECT: Set initialization
let uniqueIds: Set<UUID> = []
```

### Lazy Evaluation

```swift
// CORRECT: Lazy sequences for performance
let largeArray = (0..<1_000_000)
let evenNumbers = largeArray.lazy.filter { $0 % 2 == 0 }
```

### Property Wrappers

```swift
// CORRECT: Custom property wrapper usage
@Published var measurements: [ProcessValue<Dimension>] = []

// CORRECT: UserDefaults property wrapper
@AppStorage("refreshInterval") var refreshInterval: TimeInterval = 60
```

---

## Package-Specific Conventions

### Public API Patterns

```swift
// CORRECT: Controller pattern
public class WeatherController: ProcessController {
    public func refreshData(for location: Location) async throws -> ProcessSensor? {
        // Fetch data from service
        // Process into ProcessSensor
        // Return structured data
    }
}

// CORRECT: Service pattern (stateless)
public class CovidService {
    static func fetchDistricts(for location: Location, radius: Double) async throws -> Data? {
        // Perform HTTP request
        // Return raw data
    }
}

// CORRECT: Transformer pattern
public class WeatherTransformer: ProcessTransformer {
    override public func renderCurrent(measurements: [ProcessSelector: [ProcessValue<Dimension>]])
        -> [ProcessSelector: ProcessValue<Dimension>] {
        // Transform raw measurements into current values
    }
}
```

### Data Flow Pattern

```swift
// Service (HTTP) → Controller (Parse) → Transformer (Process) → Consumer (Display)

// 1. Service: Fetch raw data
let data = try await CovidService.fetchIncidence(id: districtId)

// 2. Controller: Parse and structure
let sensor = try await controller.refreshData(for: location)

// 3. Transformer: Process for display
let transformer = WeatherTransformer()
try transformer.renderData(sensor: sensor)

// 4. Consumer uses: transformer.current, transformer.faceplate, etc.
```

### Process Architecture

```swift
// CORRECT: ProcessValue with quality assessment
let temperature = Measurement<Dimension>(value: 20.5, unit: UnitTemperature.celsius)
let processValue = ProcessValue(value: temperature, quality: .good, timestamp: Date.now)

// CORRECT: ProcessSensor with measurements
let sensor = ProcessSensor(
    name: "Weather Station",
    location: location,
    placemark: "Berlin, Germany",
    customData: ["icon": "cloud.sun"],
    measurements: measurements,
    timestamp: Date.now
)

// CORRECT: ProcessSelector for data organization
measurements[.weather(.temperature)] = [processValue]
measurements[.weather(.humidity)] = [humidityValue]
```

### Custom Units Pattern

```swift
// CORRECT: Custom Dimension subclass with @unchecked Sendable
public class UnitRadiation: Dimension, @unchecked Sendable {
    public static let sieverts = UnitRadiation(
        symbol: "Sv/h",
        converter: UnitConverterLinear(coefficient: 1.0)
    )

    public static let microsieverts = UnitRadiation(
        symbol: "µSv/h",
        converter: UnitConverterLinear(coefficient: 0.000001)
    )

    override public class func baseUnit() -> Self {
        return sieverts as! Self
    }
}
```

### Subscription Pattern

```swift
// CORRECT: ProcessManager subscription system
public func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) {
    subscriptions.append(ProcessSubscription(id: subscriber.id, timeout: timeout * 60))
    subscribers[subscriber.id] = subscriber
}

// CORRECT: ProcessSubscriber protocol implementation
public protocol ProcessSubscriber: Identifiable {
    func refreshData(location: Location) async
    func resetData() async
}
```

### Location-Based Updates

```swift
// CORRECT: LocationManagerDelegate pattern
public protocol LocationManagerDelegate: Identifiable where ID == UUID {
    func locationManager(didUpdateLocation location: Location) -> Void
}

// CORRECT: Significant location change detection
private func significantLocationChange(previous: Location?, current: Location) -> Bool {
    guard let previous = previous else { return true }
    let deadband = Measurement(value: 100.0, unit: UnitLength.meters)
    let distance = haversineDistance(location_0: previous, location_1: current)
    return distance > deadband
}
```

### Network Resilience Pattern

```swift
// CORRECT: URLSession extension with retry logic
extension URLSession {
    public func dataWithRetry(
        from url: URL, retryCount: Int = 3, retryInterval: TimeInterval = 1.0
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        guard ReachabilityManager.shared.isConnected else {
            throw URLError(.notConnectedToInternet)
        }

        for attempt in 0..<retryCount {
            do {
                let (data, response) = try await self.data(from: url)
                return (data, response)
            } catch {
                lastError = error
                if attempt < retryCount - 1 {
                    try await Task.sleep(nanoseconds: UInt64(retryInterval * 1_000_000_000))
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}
```

### Logging Pattern

```swift
// CORRECT: Use Trace utility for structured logging
trace.debug("Fetching covid measurement districts...")
let data = try await service.fetch()
trace.debug("Fetched covid measurement districts.")

trace.error("Failed to parse response: \(error)")
```

### Platform Independence

```swift
// CORRECT: Platform conditionals for OS-specific code
#if os(iOS)
locationManager.allowsBackgroundLocationUpdates = true
locationManager.pausesLocationUpdatesAutomatically = false
#else
locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
#endif

// AVOID: UI framework dependencies (SwiftUI, UIKit, AppKit) in package
// Keep package focused on business logic and data processing
```

---

## Summary Checklist

### Before Committing Code

- [ ] All public APIs have explicit `public` access control
- [ ] All types, functions, and properties follow naming conventions
- [ ] Code is formatted with 4-space indentation
- [ ] No trailing whitespace
- [ ] Documentation comments for public APIs
- [ ] Error handling is comprehensive
- [ ] Async/await used consistently throughout
- [ ] No platform-specific UI dependencies (SwiftUI, UIKit, AppKit)
- [ ] Custom `Dimension` types conform to `@unchecked Sendable`
- [ ] Protocol conformance is clear and explicit
- [ ] MARK comments organize code sections
- [ ] No force unwrapping (!) unless absolutely safe
- [ ] Follows established package patterns (Controller/Service/Transformer)

### Code Review Focus Areas

1. **Access Control**: Correct use of public/private/internal
2. **Naming**: Clear, descriptive, follows conventions
3. **Error Handling**: Comprehensive try-catch, meaningful errors
4. **Concurrency**: Proper async/await, actor usage, Sendable conformance
5. **Architecture**: Follows Controller/Service/Transformer pattern
6. **Documentation**: Public APIs documented, complex logic explained
7. **Platform Independence**: No UI framework dependencies
8. **Performance**: Efficient algorithms, lazy evaluation where appropriate
9. **Safety**: No force unwrapping, proper optional handling
10. **Consistency**: Matches existing codebase patterns

---

*This document is maintained alongside AGENTS.md and should be updated when new patterns emerge or conventions change.*

## Build Commands

### Setup

```bash
# Check Swift version
swift --version

# Check Swift Package Manager version
swift package --version

# Install Xcode Command Line Tools (macOS - if not already installed)
xcode-select --install

# Install Swift (Linux)
# See: https://swift.org/install/linux/
```

### Development

```bash
# Build the project (debug - use during development)
swift build

# Run the application
swift run

# Run with arguments
swift run <target_name> [args]

# Run tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test
swift test --filter <test_name>

# Run tests in parallel
swift test --parallel

# Generate code coverage (requires additional setup)
swift test --enable-code-coverage
```

### Build & Deploy

```bash
# Build for release (optimized - use for final testing/deployment only)
swift build -c release

# Run release build
swift run -c release

# Build with verbose output
swift build --verbose

# Clean build artifacts
swift package clean

# Reset package cache and rebuild
swift package reset
rm -rf .build
swift build
```

### Package Management

```bash
# Initialize a new package
swift package init --type <executable|library>

# Update dependencies to latest compatible versions
swift package update

# Resolve dependencies without building
swift package resolve

# Show package dependencies
swift package show-dependencies

# Show dependency tree
swift package show-dependencies --format json

# Edit package in Xcode (macOS)
swift package generate-xcodeproj

# Open package in Xcode (macOS - Swift 5.6+)
open Package.swift
```

### Documentation

```bash
# Generate documentation (requires DocC)
swift package generate-documentation

# Preview documentation (requires DocC)
swift package --disable-sandbox preview-documentation

# Build documentation archive
swift package generate-documentation --output-path ./docs
```

### Code Quality

```bash
# Format code (requires swift-format tool)
swift-format format --in-place --recursive .

# Lint code (requires swift-format tool)
swift-format lint --recursive .

# Run with sanitizers (debug builds)
swift build --sanitize=address
swift build --sanitize=thread

# Build with warnings as errors
swift build -Xswiftc -warnings-as-errors
```

### Advanced Options

```bash
# Build for specific platform
swift build --triple <target_triple>

# Build static library
swift build -c release --static-swift-stdlib

# Show build commands
swift build --verbose

# Build with optimization level
swift build -Xswiftc -O           # Standard optimization
swift build -Xswiftc -Osize       # Optimize for size
swift build -Xswiftc -Ounchecked  # Optimize with no safety checks

# Enable additional compiler flags
swift build -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete

# List available products and targets
swift package dump-package | grep -E '(name|type)'
```

### Cross-Platform Builds

```bash
# Build for iOS (requires macOS with Xcode)
xcodebuild -scheme <scheme_name> -destination 'platform=iOS Simulator,name=iPhone 14'

# Archive for distribution (requires macOS with Xcode)
xcodebuild archive -scheme <scheme_name> -archivePath ./build/App.xcarchive

# Build universal binary (macOS)
swift build -c release --arch arm64 --arch x86_64
```

**Important**: Always use debug builds (`swift build`) during development. Debug builds compile faster and include debugging symbols. Only use release builds (`swift build -c release`) for final testing or deployment.

<!-- {integration} -->

## Commit Protocol (CRITICAL)

- **NEVER commit automatically** - always wait for explicit confirmation

Whenever asked to commit changes:

- Stage the changes
- Write a detailed but concise commit message using conventional commits format
- Commit the changes

This is **CRITICAL**!

## **Commit Message Guidelines - CRITICAL**

Follow these rules to prevent VSCode terminal crashes and ensure clean git history:

**Message Format (Conventional Commits):**

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Character Limits:**

- **Subject line**: Maximum 50 characters (strict limit)
- **Body lines**: Wrap at 72 characters per line
- **Total message**: Keep under 500 characters total
- **Blank line**: Always add blank line between subject and body

**Subject Line Rules:**

- Use conventional commit types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`
- Scope is optional but recommended: `feat(api):`, `fix(build):`, `docs(readme):`
- Use imperative mood: "add feature" not "added feature"
- No period at end of subject line
- Keep concise and descriptive

**Body Rules (if needed):**

- Add blank line after subject before body
- Wrap each line at 72 characters maximum
- Explain what and why, not how
- Use bullet points (`-`) for multiple items with lowercase text after bullet
- Keep it concise

**Special Character Safety:**

- Avoid nested quotes or complex quoting
- Avoid special shell characters: `$`, `` ` ``, `!`, `\`, `|`, `&`, `;`
- Use simple punctuation only
- No emoji or unicode characters

**Best Practices:**

- **Break up large commits**: Split into smaller, focused commits with shorter messages
- **One concern per commit**: Each commit should address one specific change
- **Test before committing**: Ensure code builds and works
- **Reference issues**: Use `#123` format in footer if applicable

**Examples:**

Good:

```text
feat(api): add KStringTrim function

- add trimming function to remove whitespace from
  both ends of string
- supports all encodings
```

Good (short):

```text
fix(build): correct static library output name
```

Bad (too long):

```text
feat(api): add a new comprehensive string trimming function that handles all edge cases including UTF-8, UTF-16LE, UTF-16BE, and ANSI encodings with proper boundary checking and memory management
```

Bad (special characters):

```text
fix: update `KString` with "nested 'quotes'" & $special chars!
```

## Semantic Versioning Protocol

**AUTOMATICALLY track version changes using semantic versioning (SemVer) in Cargo.toml.**

The current version is defined in `Cargo.toml` under `[package]` section as `version = "X.Y.Z"`.

### Version Format: MAJOR.MINOR.PATCH

**When to increment:**

1. **PATCH version** (X.Y.Z → X.Y.Z+1)
   - Bug fixes and minor corrections
   - Performance improvements without API changes
   - Documentation updates
   - Internal refactoring that doesn't affect public API
   - Example: `1.0.0` → `1.0.1`

2. **MINOR version** (X.Y.Z → X.Y+1.0)
   - New features added
   - New CLI commands or options
   - New functionality that maintains backward compatibility
   - Example: `1.0.1` → `1.1.0`

3. **MAJOR version** (X.Y.Z → X+1.0.0)
   - Breaking changes to public API
   - Removal of features or commands
   - Changes that require user action or code updates
   - Incompatible CLI changes
   - Example: `1.1.0` → `2.0.0`

### Process

After making ANY code changes:

1. Determine the type of change (fix, feature, or breaking change)
2. Update the version in `Cargo.toml` accordingly
3. Include the version change in the same commit as the code change
4. Mention version bump in commit message footer if significant

**Note:** Version changes should be included in the commit with the actual code changes, not as a separate commit.

---

## Recent Updates & Decisions

### 2025-11-22 19:15 (Single Guard Statements)

- **Updated coding standard**: Prefer single guard statements over multiple guard conditions
- **Rule**: Use separate guard statements for each condition instead of combining them with commas
- **Rationale**:
  - Each guard statement has clear, specific error handling
  - Easier to debug which condition failed
  - More flexible for different error responses per condition
  - Clearer code intent and better readability
- **Example**: Instead of `guard let data = data, let response = response else { }`, use separate guards for data and response
- **Reasoning**: Single guard statements make it easier to provide specific error messages and handle each failure case appropriately. Combined guard conditions can mask which specific condition failed during debugging.

### 2025-11-22 19:00 (Explicit Boolean Comparisons)

- **Added coding standard**: Require explicit boolean comparisons in all control flow statements
- **Rule**: Always use `if condition == true` instead of `if condition`, and `if condition == false` instead of `if !condition`
- **Implementation**: Updated all `if` and `while` statements throughout codebase to use explicit comparisons
- **Files updated**: `AranetClient.swift`, `aranetctl.swift`
- **Benefits**:
  - Improved code readability
  - Makes boolean comparisons explicit and unambiguous
  - Consistent style across the codebase
- **Reasoning**: Explicit boolean comparisons make code intent clearer and are easier to understand, especially for developers coming from languages where truthiness differs from Swift.

### 2025-11-22 18:45 (Library Package Architecture)

- **Created AranetKit library target**: Separated core Bluetooth functionality from CLI application
- **Package structure**:
  - `Sources/AranetKit/` - Library target with AranetClient and AranetTypes (reusable)
  - `Sources/aranetctl/` - Executable target with CLI and ProgressSpinner (application-specific)
- **Updated Package.swift**: Added library product and separate targets for library and executable
- **Benefits**:
  - Core Aranet functionality can be imported by other Swift projects
  - Clean separation of concerns between library code and CLI
  - Follows Swift Package Manager best practices
  - Enables easier testing and code reuse
- **Import pattern**: CLI now imports `AranetKit` to access client and types
- **Reasoning**: Standard Swift package architecture separates reusable library code from application code. This makes the Bluetooth client and data models available to other projects while keeping CLI-specific utilities in the executable target.

### 2025-11-20 14:30 (Documentation Cleanup)

- **Cleaned up README.md** to reflect no-pairing-required reality
- **Removed duplicate sections**: Consolidated two "Device Not Found" sections into one
- **Removed outdated pairing instructions**: Deleted misleading pairing steps that contradicted "No Pairing Required" feature
- **Fixed formatting issues**:
  - Removed duplicate "Example output:" headers in scan section
  - Added language specification to code blocks (changed ``` to ```text)
- **Improved troubleshooting clarity**: Updated Device Not Found section with clearer, more actionable steps
- **Reasoning**: Documentation was confusing with contradictory information about pairing. After breakthrough with F0CD3001 characteristic, pairing is no longer needed for normal operation. Documentation now accurately reflects this simplified user experience.

### 2025-11-20 (Pairing Solution - WORKING!)

- **BREAKTHROUGH**: Discovered that Aranet4 devices have two reading characteristics:
  - F0CD1503 (basic) - requires Bluetooth pairing/authentication
  - F0CD3001 (detailed) - does NOT require pairing and provides full sensor data
- **Solution**: Modified characteristic discovery to defer reads until all characteristics are found, then prioritize F0CD3001 over F0CD1503
- **Result**: Tool now works without requiring device pairing! Reads sensor data successfully from detailed characteristic
- **Implementation**: Added `availableReadingChars` set to track available characteristics, then select best one after discovery completes
- **Priority order**: Detailed (F0CD3001) > AR2 (F0CD1504) > Basic (F0CD1503)
- Successfully tested multiple reads showing CO2, temperature, humidity, pressure, battery, and status
- Clean output without verbose mode working perfectly

### 2025-11-20 (Pairing Investigation)

- Added Bluetooth pairing detection and handling
- Identified that Aranet devices require PIN-based pairing for encrypted characteristics
- Added helpful error message with pairing instructions
- Fixed service discovery to discover all services (including GAP)
- Made device name optional (uses peripheral name as fallback)
- Added encryption error detection (CBATTError code 15)
- Updated README with comprehensive pairing instructions
- Added verbose debugging mode with `--verbose` flag for troubleshooting

### 2025-11-20 (Implementation)

- Implemented core Bluetooth client for Aranet4 sensors
- Created `AranetTypes.swift` with data models (AranetReading, device types, status enums)
- Created `AranetClient.swift` with CoreBluetooth integration for scanning and reading
- Updated CLI with scan and read subcommands
- Added platform requirement: macOS 12+ for async/await support
- Used `@unchecked Sendable` for CoreBluetooth wrapper (non-Sendable framework)
- Bluetooth UUIDs defined for Aranet service (FCE0) and characteristics
- Data parsing implemented for Aranet4 format (CO2, temperature, humidity, pressure)

### 2025-11-20 (Session Init)

- Session initialized with proper project understanding
- Updated Mission Statement to reflect aranetctl Swift CLI project
- Confirmed technology stack: Swift 6.2+, Swift Argument Parser, CoreBluetooth
- Established project as Swift reimplementation of Python aranet4 library
- Identified key features: sensor readings, historical logs, device settings, BLE scanning

### 2025-10-05

- Initial AGENTS.md setup
- Established core coding standards and conventions
- Created agent-specific reference files
- Defined repository structure and governance principles
