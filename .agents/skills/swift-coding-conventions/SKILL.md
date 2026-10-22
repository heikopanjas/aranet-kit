---
name: swift-coding-conventions
description: Swift coding conventions covering naming, access control, concurrency, error handling, and protocol-oriented design. Load before writing, reviewing, or refactoring Swift code.
license: MIT
metadata:
  author: Heiko Panjas
  version: "2.2"
---

# Swift Coding Conventions

Read this skill before writing, reviewing, or refactoring Swift code in this project.
It covers naming, access control, concurrency, error handling, protocols, and more.

## Special Rules

### **IMPORTANT**: Use of Boolean literals in conditions

- **ALWAYS** use Boolean constants directly in conditions.

// CORRECT:
if needsUpdate == true {
    // Implementation
}

// INCORRECT:
if needsUpdate {
    // Implementation
}

// CORRECT:
while needsUpdate == false {
    // Implementation
}

// INCORRECT:
while !needsUpdate {
    // Implementation
}

### **IMPORTANT**: Use of nil in conditions

- **ALWAYS** compare directly with `nil` when a condition only checks whether a value is present or absent.
- **NEVER** use optional binding as an implicit nil check when the unwrapped value is not used.
- **ALWAYS** use optional binding when the unwrapped value is used in the branch body.
- A file that uses `if let` or `guard let` without any `== nil` or `!= nil` checks is not automatically non-compliant. Review whether each binding unwraps a value that is actually used.

Use this decision guide:

| Situation | Required pattern |
| --- | --- |
| Check presence only; unwrapped value unused | `if value != nil { ... }` |
| Check absence only; unwrapped value unused | `if value == nil { ... }` |
| Unwrapped value used in the branch | `if let value = value { use(value) }` or shorthand `if let value { use(value) }` |
| Discarded binding just to test presence | Forbidden: `if let _ = value { ... }` |

// CORRECT: presence check only
if location != nil {
    refreshSubscriptions()
}

// INCORRECT: implicit nil check with unused binding
if let _ = location {
    refreshSubscriptions()
}

// CORRECT: absence check only
if location == nil {
    return
}

// INCORRECT: guard with unused binding
guard let _ = location else {
    return
}

// CORRECT: optional binding because the value is used
if let location = self.location {
    process(location)
}

// CORRECT: SwiftUI branch that uses the unwrapped value
if let store {
    FooRootView(store: store)
}
else if let errorMessage {
    Text(errorMessage)
}

// INCORRECT: explicit nil check followed by force unwrap
if store != nil {
    FooRootView(store: store!)
}

### **IMPORTANT**: Explicit `self.` and `Self.` qualification for member access

- **ALWAYS** qualify access to **instance** properties and methods with `self.`.
- **ALWAYS** qualify access to **type-level** members (declared with `static` or `class`) with `Self.` when accessed from inside the same type. Use the concrete type name (e.g. `MyType.shared`) only when referring to a different type.
- Both rules apply in **every** context: method bodies, initializers, computed properties, property observers, closures, escaping closures, `@MainActor` code, SwiftUI views and view builders, and result builders.
- Both rules cover reads, writes, method calls, and the use of members as arguments.
- The only unqualified identifiers permitted inside a type are local variables, function parameters, and globally scoped symbols (free functions, top-level constants, imported APIs).
- Rationale: explicit qualification makes the scope of every identifier immediately visible — `self.` marks instance state, `Self.` marks type-level state, and unqualified names are guaranteed to be local or global. This eliminates shadowing bugs, makes refactors safer, and keeps the codebase consistent and greppable.

```swift
// CORRECT: instance members use self., type-level members use Self.
final class LocationCoordinator {
    static let defaultTimeout: TimeInterval = 30
    static func makeDefault() -> LocationCoordinator {
        return LocationCoordinator(manager: CLLocationManager())
    }

    private var location: CLLocation?
    private let manager: CLLocationManager

    init(manager: CLLocationManager) {
        self.manager = manager
        self.manager.delegate = self
    }

    func refresh() {
        self.manager.requestLocation()
        self.scheduleTimeout(after: Self.defaultTimeout)
        if let location = self.location {
            self.process(location)
        }
    }

    private func process(_ location: CLLocation) {
        self.location = location
    }

    private func scheduleTimeout(after seconds: TimeInterval) {
        // ...
    }
}

// INCORRECT: implicit member access (instance and type-level)
final class LocationCoordinator {
    static let defaultTimeout: TimeInterval = 30

    private var location: CLLocation?
    private let manager: CLLocationManager

    init(manager: CLLocationManager) {
        self.manager = manager
        manager.delegate = self                  // missing self.
    }

    func refresh() {
        manager.requestLocation()                // missing self.
        scheduleTimeout(after: defaultTimeout)   // missing self. and Self.
        if let location {                        // shadows the property; unclear
            process(location)                    // missing self.
        }
    }
}
```

### Force Unwrapping

- **NEVER** use force unwrapping (`!`) for optionals. **ALWAYS** use optional binding (`if let`, `guard let`) or optional chaining.

### Force Try

- **NEVER** use `try!` for error handling. **ALWAYS** use `do-catch` or `try?` for safe error handling.

### Return of arrays and dictionaries from functions

- **NEVER** return `nil` to indicate the absence of data. **ALWAYS** return empty arrays or dictionaries from functions instead.
- **NEVER** return optional arrays or dictionaries to indicate the absence of data. **ALWAYS** return empty arrays or dictionaries from functions instead.

### No implicit returns

- **NEVER** use implicit returns for functions, methods, classes, structs, enums, computed properties, and protocols. **ALWAYS** use explicit return values.
- Multi-line value-producing closures **MUST** use explicit `return`.
- Concise single-line functional closures are allowed to use Swift shorthand style when passed directly to APIs such as `map`, `filter`, `compactMap`, `sorted`, `reduce`, `forEach`, `first(where:)`, `contains(where:)`, or SwiftUI builders.
- Do not rewrite clear single-line functional closures into loops solely to avoid implicit returns.

```swift
// CORRECT: concise single-line functional style
let regions = values.map(Region.init(source:)).filter { $0 != .unknown }
concreteRegions.sorted().forEach { arguments += [$0.rawValue] }

// CORRECT: multi-line value-producing closure uses explicit return
let regions = values.filter { value in
    return value != .unknown
}

// INCORRECT: multi-line value-producing closure with implicit return
let regions = values.filter { value in
    value != .unknown
}
```

## File Organization

### **IMPORTANT**: One primary type per file

- **Each top-level `class`, `struct`, `enum`, or `actor` MUST live in its own `.swift` file.**
- **File name MUST match the type name** (PascalCase): `FooPresenter.swift` contains `FooPresenter`; `FooManager.swift` contains `FooManager`.
- This applies equally to domain types, presenters, services, views (`struct …: View`), and actors — not only classes.
- **Do not bundle** sibling top-level types into one file because they are empty subclasses, thin wrappers, co-located DTOs, or “related” helpers.

**Allowed exceptions (narrow):**

- **Private nested types** declared inside a parent type (e.g. nested enums on a public enum)
- **Small, tightly-coupled helper types** that exist only to support the primary type and are not standalone API — use sparingly; when in doubt, split into a separate file

**NOT allowed:**

```swift
// INCORRECT: multiple top-level classes in one file
open class BasePresenter: AbstractPresenter {}
public final class BarPresenter: BasePresenter {}
public final class FooPresenter: BasePresenter {}

// INCORRECT: multiple top-level structs/enums in one file
enum TimeSeriesInterval { case hourly }
struct TimeSeriesPoint { let value: Double }
class ExamplePredictor {}
```

```swift
// CORRECT: one primary type per file
// File: FooPresenter.swift
@MainActor
@Observable
public final class FooPresenter: BasePresenter {}

// File: TimeSeriesPoint.swift
struct TimeSeriesPoint {
    let timestamp: Date
    let value: Double
}
```

**Protocols:** prefer one primary protocol per file when the protocol is a shared contract (`FooControllerProtocol.swift`). Multiple small related protocols in one file is discouraged; split when each protocol is consumed independently.

**Extensions:** `TypeName+Feature.swift` is allowed for extensions on an existing type defined elsewhere; the extension file must not introduce additional top-level types.

## Naming Conventions

### General Rules

- Use clear, descriptive names that convey intent
- Prefer full words over abbreviations
- Use American English spelling

### Types (Classes, Structs, Enums, Protocols)

```swift
// CORRECT: PascalCase for types
public class FooManager {}
public struct Location {}
public enum FooQuality {}
public protocol FooController {}

// INCORRECT
public class processManager {}  // Wrong case
public struct location {}       // Wrong case
```

### Properties & Variables

```swift
// CORRECT: camelCase for properties and variables
    let locationManager = LocationManager()
    var subscriptions: [FooSubscription] = []
    private let updateInterval: TimeInterval = 60

// INCORRECT
    let LocationManager = LocationManager()  // Wrong case
    var Subscriptions: [FooSubscription] = []  // Wrong case
```

### Functions & Methods

```swift
// CORRECT: camelCase, descriptive action verbs
    func refreshData(for location: Location) async throws -> FooSensor?
    func updateLocation(location: Location) -> Void
    private func significantLocationChange(previous: Location?, current: Location) -> Bool

// INCORRECT
    func RefreshData() {}  // Wrong case
    func upd() {}  // Too abbreviated
    func location_update() {}  // Snake case
```

### Protocols

```swift
// CORRECT: Protocol names ending in -able, -ible indicate capability
protocol Sendable {}  // Standard library example

// INCORRECT: Use descriptive protocol names
public protocol FooController {}
public protocol LocationManagerDelegate: Identifiable where ID == UUID {}
```

## Code Structure

### Braces for functions

- Function opening braces follow `.swift-format` default Apple style: same line as the signature.
- Do not manually restyle function braces to a next-line form that the formatter cannot enforce.

```swift
// CORRECT: Opening brace on same line, closing brace on new line
    func updateSubscriptions() {
        // Implementation
    }

// INCORRECT: Opening brace on new line, closing brace on new line
    func updateSubscriptions()
    {
        // Implementation
    }
```

### Braces for classes, structs, enums, and control flow statements

```swift
// CORRECT: Opening brace on same line, closing brace on new line
public class FooManager {
    func updateSubscriptions() {
        // Implementation
    }

    // Declarations and methods here
}

// INCORRECT: Opening brace on new line, closing brace on new line
public class FooManager
{
    func updateSubscriptions() {
        // Implementation
    }

    // Declarations and methods here
}

// CORRECT: Opening brace on same line, closing brace on new line
    for subscription in subscriptions {
        subscription.update(timeout: updateInterval)
    }

// INCORRECT: Opening brace on new line, closing brace on new line
    for subscription in subscriptions
    {
        subscription.update(timeout: updateInterval)
    }
```

### Control-flow keyword line breaks

- **ALWAYS** place `else` and `catch` on their own line after the previous block's closing brace.
- This matches `.swift-format` with `lineBreakBeforeControlFlowKeywords: true`.

```swift
// CORRECT:
if needsUpdate == true {
    refreshSubscriptions()
}
else {
    waitForNextUpdate()
}

// INCORRECT:
if needsUpdate == true {
    refreshSubscriptions()
} else {
    waitForNextUpdate()
}

// CORRECT:
do {
    try loadConfiguration()
}
catch {
    handle(error)
}

// INCORRECT:
do {
    try loadConfiguration()
} catch {
    handle(error)
}
```

### Indentation

- Use **4 spaces** for indentation (no tabs)
- Align continuation lines with the opening delimiter

### Line Length

- Target maximum: **187 characters** per line
- Break very long lines at logical points (parameters, operators, closures)

```swift
// CORRECT: Keep long function signatures on one line if possible
public func dataWithRetry(from url: URL, retryCount: Int = 3, retryInterval: TimeInterval = 1.0, delegate: (any URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse) {
    // Implementation
}

// INCORRECT: Break long function signatures
public func dataWithRetry(
    from url: URL, retryCount: Int = 3,
    retryInterval: TimeInterval = 1.0,
    delegate: (any URLSessionTaskDelegate)? = nil
) async throws -> (Data, URLResponse) {
    // Implementation
}
```

## Access Control

### Access Levels (Most to Least Restrictive)

1. `private` - Only visible within the current declaration
2. `fileprivate` - Visible within the same source file
3. `internal` - Visible within the module (default)
4. `public` - Visible to consumers of the module
5. `open` - Visible and subclassable outside the module

### Rules

- **Always explicit**: Mark APIs as `public` explicitly; avoid relying on default `internal`
- **Minimize exposure**: Only expose what consumers need
- **Private by default**: Start with `private`, increase visibility as needed
- **No `open` classes**: Package doesn't require subclassing from consumers

## Function Declarations

### Parameter Labels

```swift
// CORRECT: Descriptive external labels
func updateLocation(location: Location) -> Void {}
func add(subscriber: any FooSubscriber, timeout: TimeInterval) -> Void {}

// INCORRECT: Incomplete or non-descriptive external labels
func updateLocation(loc: Location) -> Void {}
func add(s: any FooSubscriber, t: TimeInterval) -> Void {}
```

### Default Parameters

```swift
// CORRECT: Default parameters at end
public func dataWithRetry(from url: URL, retryCount: Int = 3, retryInterval: TimeInterval = 1.0, delegate: (any URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse) {
    // Implementation
}

// INCORRECT:
public func dataWithRetry(from url: URL? = nil, retryCount: Int, retryInterval: TimeInterval = 1.0, delegate: (any URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse) {
    // Implementation
}
```

### Return Type Void

```swift
// CORRECT: Explicit Void return type
public func updateLocation(location: Location) -> Void {
    // Implementation
}

// INCORRECT: Omit return type for Void
public func updateLocation(location: Location) {
    // Implementation
}
```

## Control Flow

### If Statements

```swift
// CORRECT: Standard if statement
public func updateLocation(location: Location) -> Void {
    if location != nil {
        refreshSubscriptions()
    }
}

// CORRECT: If-let for optional binding when the value is used
public func updateLocation(location: Location) -> Void {
    if let location = self.location {
        delegate.locationManager(didUpdateLocation: location)
    }
}

// CORRECT: Explicit nil check when only presence matters
public func updateLocation(location: Location) -> Void {
    if self.location != nil {
        refreshSubscriptions()
    }
}

// CORRECT: Multiple conditions
if needsUpdate == true {
    if location != nil {
        self.location = location
        if let delegate = self.delegate {
            delegate.locationManager(didUpdateLocation: location)
        }
    }
}

// INCORRECT: Nested multiple conditions
if needsUpdate == true && location != nil {
    self.location = location
    if let delegate = self.delegate {
        delegate.locationManager(didUpdateLocation: location)
    }
}

```

### For Loops

- `.swift-format` currently has `UseWhereClausesInForLoops` enabled.
- Treat formatter suggestions that add `where` clauses as optional when the
  condition would become complex or would obscure the style-guide preference for
  clear, nested control flow.
- Keep simple `for ... where ...` loops when they remain easier to read than an
  inner `if`.

### Guard Statements

```swift
// CORRECT: Guard for preconditions and early exits
guard NetworkMonitor.shared.isConnected == true else {
    throw URLError(.notConnectedToInternet)
}

guard let url = URL(string: "https://api.example.com/data") else {
    return nil
}

// CORRECT: Multiple guard conditions
guard let data = data else {
    throw NetworkError.invalidResponse
}

guard let response = response as? HTTPURLResponse,
    (200...299).contains(response.statusCode) else {
    throw NetworkError.invalidResponse
}

// INCORRECT: Multiple nested guard conditions
guard let data = data,
    let response = response as? HTTPURLResponse,
    (200...299).contains(response.statusCode) else {
    throw NetworkError.invalidResponse
}

// CORRECT: Guard for early return only
public func updateLocation(location: Location) -> Void {
    // No function code before guard

    guard let location = self.location else {
        return
    }

    // Function code continues here
    delegate.locationManager(didUpdateLocation: location)
}

// INCORRECT: Guard with code before it (not allowed)
public func updateLocation(location: Location) -> Void {
    // Function code before guard (not allowed)
    let timeSinceLastUpdate = Date.now.timeIntervalSince(lastUpdate)
    if timeSinceLastUpdate < Date().timeIntervalSince(lastUpdate) {
        return
    }

    guard let location = self.location else {
        return
    }

    // Function code continues here
    delegate.locationManager(didUpdateLocation: location)
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

// INCORRECT: Switch with multiple cases
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
let (result = condition) == true ? trueValue : falseValue

// INCORRECT: No braces for expressions
let result = condition == true ? trueValue : falseValue

// INCORRECT: Nested ternary (use if-else instead)
let result = condition1 ? value1 : (condition2 ? value2 : value3)  // Hard to read
```

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

### Try-Catch Blocks

### Optional Try

```swift
// CORRECT: try? for optional result
if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
    // Use placemark
}

// INCORRECT: NEVER use try!
let config = try! Configuration.load()  // Not guaranteed to succeed
```

## Protocols & Extensions

### Extension Organization

```swift
// CORRECT: Organize extensions by purpose
// File: FooManager.swift

public class FooManager {
    // Core implementation
}

extension FooManager: LocationManagerDelegate {
    public func locationManager(didUpdateLocation location: Location) -> Void {
        // Implementation
    }
}

extension FooManager {
    public func add(subscriber: any FooSubscriber, timeout: TimeInterval) -> Void {
        // Implementation
    }
}
```

## Generics

### Generic Types

```swift
// CORRECT: Generic struct with type constraints
public struct FooValue<T: Dimension>: Identifiable {
    public let id = UUID()
    public let value: Measurement<T>
    public let quality: FooQuality
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
private var subscribers: [UUID: any FooSubscriber] = [:]

public func add(subscriber: any FooSubscriber, timeout: TimeInterval) -> Void {
    subscribers[subscriber.id] = subscriber
}
```

## Comments & Documentation

### Code Comments

```swift
// CORRECT: Comment explains why, not what
// Check if device is connected before attempting network request
guard NetworkMonitor.shared.isConnected == true else {
    throw URLError(.notConnectedToInternet)
}

// INCORRECT: States the obvious
// Set location to new location
self.location = location
```

### Documentation Comments

```swift
// CORRECT: DocC-style documentation
/// A simple and fast logging facility with support for different log levels and detailed timestamps.
public class Logger {
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
    public init(minimumLevel: Level = .debug, showColors: Bool = true, dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSS", logFile: String? = nil) {
        // Implementation
    }
}
```

### TODO/FIXME Comments

```swift
// TODO: Implement caching mechanism for remote data
// FIXME: Handle edge case when location is exactly on boundary
// NOTE: This assumes the API always returns valid data
```

## Formatting & Whitespace

### Blank Lines

```swift
// CORRECT: Blank line between logical sections
public class FooManager {
    public let id = UUID()
    public static let shared = FooManager()

    private let locationManager = LocationManager()
    private var location: Location?

    private init() {
        self.locationManager.delegate = self
    }

    public func refreshSubscriptions() -> Void {
        // Implementation
    }
}

// INCORRECT: No blank line between logical sections
public class FooManager {
    public let id = UUID()
    public static let shared = FooManager()
    private let locationManager = LocationManager()
    private var location: Location?

    private init() {
        self.locationManager.delegate = self
    }
    public func refreshSubscriptions() -> Void {
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

// INCORRECT: No space after comma, around operators
let values = [1,2,3,4]
let sum = a+b
let range = 0.0...100.0

// CORRECT: Space around range operators
for i in 0 ..< count { }
let range = 0 ... 10

// INCORRECT: No space around range operators
for i in 0..<count { }
let range = 0...10

// CORRECT:
var measurements: [FooSelector: [FooValue<Dimension>]] = [:]
func add(subscriber: any FooSubscriber, timeout: TimeInterval) -> Void {}
var dict: [String: Int]  // Spaces before colons

// INCORRECT:
var measurements : [FooSelector : [FooValue<Dimension>]] = [ : ]
func add(subscriber : any FooSubscriber, timeout : TimeInterval) -> Void { }
var dict : [String : Int]  // Spaces before colons
```

## Swift-Specific Patterns

### Optionals

```swift
// CORRECT: Optional binding when the unwrapped value is used
if let location = self.location {
    process(location)
}

// CORRECT: Explicit nil comparison when only presence matters
if self.location != nil {
    refreshSubscriptions()
}

// CORRECT: Optional binding with guard
guard let location = self.location else {
    return
}

// CORRECT: Optional chaining
let count = subscribers[id]?.subscriptions.count

// CORRECT: Nil coalescing
let value = optionalValue ?? defaultValue

// INCORRECT:  NEVER force unwrapping
let value = optionalValue!
```

### Type Inference

```swift
// CORRECT: Let Swift infer obvious types
let manager = FooManager.shared
let id = UUID()
let values = [1, 2, 3]

// CORRECT: Explicit types for clarity
let timeout: TimeInterval = 60
let measurements: [FooSelector: [FooValue<Dimension>]] = [:]

// INCORRECT: Redundant type annotations
let manager: FooManager = FooManager.shared  // Type obvious
```

### Closures

```swift
// CORRECT: Opening brace on same line for closures
Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
    self.updateSubscriptions()
}

// INCORRECT: Opening brace on new line for closures
Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true)
{ _ in
    self.updateSubscriptions()
}

// CORRECT: Shorthand when simple
items.map { $0.value * 2 }

// INCORRECT: Explicit closure parameters when simple
items.map { item in item.value * 2 }
```

### Lazy Evaluation

```swift
// CORRECT: Lazy sequences for performance
let largeArray = (0..<1_000_000)
let evenNumbers = largeArray.lazy.filter { $0 % 2 == 0 }

// INCORRECT: Immediate sequences for performance
let largeArray = (0..<1_000_000)
let evenNumbers = largeArray.filter { $0 % 2 == 0 }
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

// INCORRECT: UI framework dependencies (SwiftUI, UIKit, AppKit) in package
// Keep package focused on business logic and data processing
```
