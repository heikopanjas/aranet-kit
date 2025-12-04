# Project Instructions for AI Coding Agents

**Last updated:** 2025-12-04 10:00

<!-- {mission} -->

## Mission Statement

**aranetcli** is a Swift command-line tool for interacting with Aranet4, Aranet2, Aranet Radiation, and Aranet Radon Plus Bluetooth sensors. The project provides a modern Swift reimplementation of the Python-based aranet4 library, offering native performance and type safety for reading sensor data, fetching historical logs, and managing device settings.

Key features:

- Read current sensor measurements (CO2, temperature, humidity, pressure)
- Monitor sensor values with periodic automatic updates
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

## Swift Coding Conventions

*Last updated: November 22, 2025*

This document defines project-specific coding conventions for aranetcli. Standard Swift conventions (naming, syntax, etc.) are assumed. Code formatting and style are managed by swift-format configuration.

---

## Project-Specific Code Style

### Boolean Comparisons

**Always use explicit comparisons with boolean values.**

```swift
// CORRECT: Explicit boolean comparisons
if verbose == true {
    print("Debug mode enabled")
}

if isEnabled == false {
    return
}

// INCORRECT: Implicit boolean checks
if verbose { }           // Wrong
if !isEnabled { }        // Wrong
```

**Rationale**: Explicit comparisons make code intent clearer and improve readability, especially for developers from other language backgrounds.

### Guard Statements

**Prefer single guard statements over multiple guard conditions.**

```swift
// CORRECT: Single guard statements (preferred)
guard let data = data else {
    throw NetworkError.noData
}

guard let response = response as? HTTPURLResponse else {
    throw NetworkError.invalidResponse
}

guard (200...299).contains(response.statusCode) else {
    throw NetworkError.serverError(statusCode: response.statusCode)
}

// AVOID: Multiple guard conditions
guard let data = data,
      let response = response as? HTTPURLResponse,
      (200...299).contains(response.statusCode) else {
    throw NetworkError.invalidResponse  // Which condition failed?
}
```

**Rationale**: Single guard statements enable specific error handling for each condition, making debugging easier and allowing different error responses per condition.

---

## Package Architecture Patterns

## Package Architecture Patterns

### Library Structure

**aranetcli** follows Swift Package Manager best practices with clear separation between library and executable:

- **AranetKit** (library): Core Bluetooth client, data models, reusable components
- **AranetCli** (executable): CLI application, command handling, user interface

### Controller/Service Pattern

```swift
// Service: Stateless data fetching
public class AranetClient {
    func readCurrentReadings(from deviceId: String, verbose: Bool) async throws -> AranetReading {
        // Bluetooth communication
    }
}

// CLI: Command handling and presentation
@main
struct AranetCLI: AsyncParsableCommand {
    @Command var read: ReadCommand
    @Command var scan: ScanCommand
}
```

### Sendable Conformance for CoreBluetooth

CoreBluetooth types are not Sendable. Use `@unchecked Sendable` wrapper pattern:

```swift
@MainActor
public class AranetClient: NSObject, @unchecked Sendable {
    // Bluetooth communication on main actor
}
```

### Data Models

Follow standard Swift value type patterns:

```swift
public struct AranetReading: Sendable {
    public let co2: Int
    public let temperature: Double
    public let humidity: Int
    // ...
}

public enum AranetDeviceType: String, Sendable {
    case aranet4 = "Aranet4"
    case aranet2 = "Aranet2"
    // ...
}
```

---

## Code Review Checklist

### Before Committing

- [ ] **Boolean comparisons are explicit** (`== true`, `== false`)
- [ ] **Guard statements are single-condition** (not combined with commas)
- [ ] **Public APIs have explicit access control** (`public`, `private`)
- [ ] **File names match primary type names**
- [ ] **CoreBluetooth wrappers use `@MainActor` and `@unchecked Sendable`**
- [ ] **Error handling is comprehensive** (no silent failures)
- [ ] **Async/await used for concurrency** (no completion handlers)
- [ ] **Code builds without warnings** (`swift build`)

### Code Quality Focus

1. **Access Control**: Correct use of `public`/`private`, minimize API surface
2. **Error Handling**: Meaningful errors with context
3. **Concurrency**: Proper async/await, actor isolation
4. **Architecture**: Clean separation between library and CLI
5. **Readability**: Clear intent, explicit comparisons, single-purpose guards

---

## Formatting & Documentation

**Code formatting and style are managed by swift-format.** See `.swift-format` configuration file for rules.

**Documentation**: Use DocC-style `///` comments for public APIs. Explain *why*, not *what*.

---

*Standard Swift conventions (PascalCase types, camelCase properties, etc.) are assumed and not documented here.*

## Aranet Device Data Formats

This section provides detailed byte-level documentation for all Aranet device data formats. All values are stored in little-endian (LE) byte order unless otherwise specified.

### Overview

Aranet devices use Bluetooth Low Energy (BLE) characteristics to transmit sensor data. Different characteristics provide different levels of detail:

- **Detailed characteristics** (F0CD3001, F0CD3003): Provide full sensor data including interval and ago values, no pairing required
- **Basic characteristics** (F0CD1503, F0CD1504): Provide core sensor data, may require pairing

### Aranet4 Device Formats

#### F0CD3001 - Detailed Current Readings (13 bytes)

**Characteristic UUID:** `F0CD3001-95DA-4F4B-9AC8-AA55D312AF0C`  
**Python struct format:** `<HHHBBBHH`  
**Total size:** 13 bytes  
**Pairing required:** No

**Byte Structure:**

```
Bytes 0-1:   CO2 (UInt16 LE) - CO2 concentration in ppm
Bytes 2-3:   Temperature (UInt16 LE) - temperature × 20 in 0.05°C units
             Actual temperature = value / 20.0
Bytes 4-5:   Pressure (UInt16 LE) - pressure × 10 in 0.1 hPa units
             Actual pressure = value / 10.0
Byte 6:      Humidity (UInt8) - relative humidity percentage (0-100)
Byte 7:      Battery (UInt8) - battery level percentage (0-100)
Byte 8:      Status (UInt8) - status color/alert (0=Error, 1=Green, 2=Yellow, 3=Red)
Bytes 9-10:  Interval (UInt16 LE) - measurement interval in seconds
Bytes 11-12: Ago (UInt16 LE) - seconds since last update
```

**Example Parsing:**

```swift
offset = 0
let co2 = readUInt16LE()           // Bytes 0-1
let tempRaw = readUInt16LE()       // Bytes 2-3
let pressureRaw = readUInt16LE()   // Bytes 4-5
let humidity = readUInt8()         // Byte 6
let battery = readUInt8()           // Byte 7
let statusRaw = readUInt8()         // Byte 8
let interval = readUInt16LE()      // Bytes 9-10
let ago = readUInt16LE()           // Bytes 11-12

let temperature = Double(tempRaw) / 20.0
let pressure = Double(pressureRaw) / 10.0
```

#### F0CD1503 - Basic Current Readings (6 bytes)

**Characteristic UUID:** `F0CD1503-95DA-4F4B-9AC8-AA55D312AF0C`  
**Python struct format:** `<HHHBBB`  
**Total size:** 6 bytes  
**Pairing required:** Yes

**Byte Structure:**

```
Bytes 0-1:   CO2 (UInt16 LE) - CO2 concentration in ppm
Bytes 2-3:   Temperature (UInt16 LE) - temperature × 20 in 0.05°C units
             Actual temperature = value / 20.0
Bytes 4-5:   Pressure (UInt16 LE) - pressure × 10 in 0.1 hPa units
             Actual pressure = value / 10.0
Byte 6:      Humidity (UInt8) - relative humidity percentage (0-100)
Byte 7:      Battery (UInt8) - battery level percentage (0-100)
Byte 8:      Status (UInt8) - status color/alert (0=Error, 1=Green, 2=Yellow, 3=Red)
```

**Note:** This format does not include interval or ago values. Use F0CD3001 for complete data.

---

### Aranet2 Device Format

#### F0CD1504 - Current Readings (10 bytes)

**Characteristic UUID:** `F0CD1504-95DA-4F4B-9AC8-AA55D312AF0C`  
**Python struct format:** `<HHHBHHB`  
**Total size:** 10 bytes (device type byte + 9 data bytes)  
**Pairing required:** Yes (for F0CD1504), No (for F0CD3003 detailed variant)

**Byte Structure:**

```
Byte 0:      Device type (0x02 = Aranet2)
Bytes 1-2:   Interval (UInt16 LE) - measurement interval in seconds
Bytes 3-4:   Ago (UInt16 LE) - seconds since last update
Byte 5:      Battery (UInt8) - battery level percentage (0-100)
Bytes 6-7:   Temperature (UInt16 LE) - temperature × 20 in 0.05°C units
             Actual temperature = value / 20.0
Byte 8:      Humidity (UInt8) - relative humidity percentage (0-100)
Byte 9:      Status (UInt8) - status flags (bits 0-1: humidity status, bits 2-3: temperature status)
```

**Example Parsing:**

```swift
offset = 1  // Skip device type byte
let interval = readUInt16LE()    // Bytes 1-2
let ago = readUInt16LE()         // Bytes 3-4
let battery = readUInt8()        // Byte 5
let tempRaw = readUInt16LE()     // Bytes 6-7
let humidity = readUInt8()       // Byte 8
let statusRaw = readUInt8()      // Byte 9

let temperature = Double(tempRaw) / 20.0
let statusHumidity = Status(rawValue: statusRaw & 0b0011)
let statusTemperature = Status(rawValue: (statusRaw & 0b1100) >> 2)
```

---

### Aranet Radiation Device Formats

#### F0CD3003 - Detailed Current Readings (48 bytes)

**Characteristic UUID:** `F0CD3003-95DA-4F4B-9AC8-AA55D312AF0C`  
**Python struct format:** `<HHHBIQQB` (for first 28 bytes)  
**Total size:** 48 bytes  
**Pairing required:** No

**Byte Structure (48 bytes total):**

The first 28 bytes follow the same `<HHHBIQQB` format as F0CD1504:

The F0CD3003 characteristic returns 48 bytes of data for Aranet Radiation devices. The format differs from F0CD1504 (28 bytes) and requires specific byte positioning.

**Byte Structure (48 bytes total):**

The first 28 bytes follow the same `<HHHBIQQB` format as F0CD1504:

```
Byte 0:     Device type (0x04 = Aranet Radiation)
Bytes 0-1:  First H (UInt16 LE) - includes device type byte, value[0] in Python struct unpack
Bytes 2-3:  Interval (UInt16 LE) - measurement interval in seconds (value[1] in Python)
Bytes 4-5:  Ago (UInt16 LE) - seconds since last update (value[2] in Python)
Byte 6:     Battery (UInt8) - battery level percentage (0-100) (value[3] in Python)
Bytes 7-10: Rate (UInt32 LE) - radiation dose rate in nSv/h (NOT multiplied by 10) (value[4] in Python)
Bytes 11-18: Total (UInt64 LE) - cumulative radiation dose in nSv (value[5] in Python)
Bytes 19-26: Duration (UInt64 LE) - measurement duration in seconds (value[6] in Python)
Byte 27:    Unknown/padding (UInt8) - (value[7] in Python)
Bytes 28-47: Extended data (20 bytes, currently unused)
```

**Note:** The Python struct format `<HHHBIQQB` unpacks bytes 0-27, where the first `H` (bytes 0-1) includes the device type byte. When parsing in Swift, skip bytes 0-1 (set offset = 2), then read interval from bytes 2-3 and ago from bytes 4-5.

**Important Notes:**

- **Rate format**: For F0CD3003, the rate is stored as nSv/h directly (NOT multiplied by 10 like F0CD1504)
- **Data model**: `radiationRate` in `AranetReading` is stored in nSv/h; `formatOutput()` converts to µSv/h for display
- **Duration**: Represents total time the sensor has been measuring since last reset (typically 8+ days for long-running sensors)
- **Total dose**: Cumulative dose since last counter reset, stored in nanosieverts (nSv)

**Comparison with F0CD1504:**

- F0CD1504: 28 bytes, rate stored as nSv/h × 10, requires pairing
- F0CD3003: 48 bytes, rate stored as nSv/h, no pairing required

**Example Parsing:**

```swift
offset = 2  // Skip bytes 0-1 (device type + first H from Python struct)
let interval = readUInt16LE()    // Read bytes 2-3 (value[1] in Python)
let ago = readUInt16LE()         // Read bytes 4-5 (value[2] in Python)
let battery = readUInt8()        // Read byte 6 (value[3] in Python)
let radiationRateRaw = readUInt32LE()  // Read bytes 7-10 (value[4] in Python, nSv/h)
let radiationTotal = readUInt64LE()    // Read bytes 11-18 (value[5] in Python, nSv)
let radiationDuration = readUInt64LE() // Read bytes 19-26 (value[6] in Python, seconds)
// Store rate as-is in nSv/h (formatOutput converts to µSv/h)
```

---

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

### 2025-12-04 10:00 (Scan Reliability Improvement)

- **Issue**: Scan command was failing to detect devices approximately 50% of the time
- **Root cause**: Default 5-second scan timeout was too short for Aranet devices which advertise infrequently to conserve battery
- **Solution**: Increased default scan timeout from 5 seconds to 10 seconds
- **Changes**:
  - `AranetCli.swift`: Changed `Scan` command default timeout from 5.0 to 10.0 seconds
  - `AranetClient.swift`: Updated library default timeout from 5.0 to 10.0 seconds
  - Added verbose logging when scan starts and when devices are discovered
  - Updated documentation to explain why longer timeouts improve discovery reliability
- **Also fixed**: Boolean comparison style in `didDiscover` delegate method to use explicit `== false` comparison
- **Reasoning**: Aranet devices advertise at low frequencies to preserve battery life. The Python implementation uses 10 seconds as the default. Matching this default improves discovery reliability without significantly impacting user experience.

### 2025-11-22 23:00 (Comprehensive Aranet Device Data Format Documentation)

- **Created comprehensive data format section**: Added detailed byte-level documentation for all Aranet device types
- **Documented formats**:
  - Aranet4: F0CD3001 (detailed, 8 bytes) and F0CD1503 (basic, 6 bytes)
  - Aranet2: F0CD1504 (8 bytes)
  - Aranet Radiation: F0CD3003 (48 bytes, detailed) and F0CD1504 (28 bytes, basic)
  - Aranet Radon: F0CD3003 (47 bytes, documented but not implemented)
- **Byte-level details**:
  - Exact byte positions for all fields
  - Data type specifications (UInt8, UInt16 LE, UInt32 LE, UInt64 LE)
  - Encoding formulas (temperature × 20, pressure × 10, radiation rate formats)
  - Python struct format references for each characteristic
  - Pairing requirements for each format
- **Common encoding notes**: Added section explaining temperature, pressure, radiation rate, status, and interval/ago encoding conventions
- **Comparison tables**: Added comparison table for Aranet Radiation characteristics
- **Reasoning**: Comprehensive byte-level documentation enables accurate parsing, debugging, and future implementation of additional device types. Critical reference for maintainers and developers working with raw BLE data.

### 2025-11-22 22:30 (F0CD3003 Data Format Documentation)

- **Documented F0CD3003 byte structure**: Added comprehensive data format specification section to AGENTS.md
- **Format details**:
  - 48-byte structure with first 28 bytes following `<HHHBIQQB` format (same as F0CD1504)
  - Rate stored as nSv/h (not multiplied by 10 like F0CD1504)
  - Correct byte offsets: interval (2-3), ago (4-5), battery (6), rate (7-10), total (11-18), duration (19-26)
  - First UInt16 (bytes 0-1) includes device type byte and should be skipped entirely (set offset = 2)
  - Extended data section (28-47) currently unused
- **Comparison**: Documented differences between F0CD3003 (48 bytes, no pairing) and F0CD1504 (28 bytes, requires pairing)
- **Parsing example**: Included Swift code example showing correct parsing sequence
- **Reasoning**: Clear documentation of data format prevents future parsing errors and helps maintainers understand the byte structure. Critical for debugging and ensuring correct field extraction.

### 2025-11-22 22:00 (Aranet Radiation Device Support - No Pairing Required)

- **Added F0CD3003 support**: Discovered that Aranet Radiation devices have two reading characteristics similar to Aranet4:
  - F0CD1504 (AR2 basic) - requires Bluetooth pairing/authentication
  - F0CD3003 (AR2 detailed) - does NOT require pairing and provides full sensor data
- **Solution**: Added `characteristicCurrentReadingsAR2Detailed` UUID and updated priority order to check F0CD3003 before F0CD1504
- **Priority order updated**: Detailed (Aranet4 F0CD3001) > AR2 Detailed (F0CD3003) > AR2 Basic (F0CD1504) > Basic (Aranet4 F0CD1503)
- **Result**: Tool now reads from Aranet Radiation devices without requiring device pairing! Successfully reads radiation dose rate, total dose, duration, battery, and timing data
- **Implementation**:
  - Added `characteristicCurrentReadingsAR2Detailed` UUID constant
  - Updated characteristic discovery to detect F0CD3003
  - Updated priority logic to prefer F0CD3003 over F0CD1504
  - Parsing already supported F0CD1504 format, which works for F0CD3003 (48 bytes vs 28 bytes, but compatible format)
- **Format**: F0CD3003 returns 48 bytes with different structure than F0CD1504 (see Data Format Specifications section)
- **Testing**: Successfully tested reading from Aranet Radiation device "30F9A" showing correct dose rate (0.03-0.04 µSv/h), total dose (0.015 mSv), and duration (8d 2h)
- **Reasoning**: Following the same pattern as Aranet4, Radiation devices have a detailed characteristic that doesn't require pairing. This provides a seamless user experience without needing to pair devices.

### 2025-11-22 21:00 (Comprehensive API Documentation)

- **Added DocC-style documentation**: Comprehensive documentation added to all public APIs in AranetClient.swift
- **Documented types**:
  - `AranetUUID` struct with all Bluetooth service and characteristic UUIDs
  - `AranetError` enum with detailed error descriptions
  - `AranetClient` class with usage examples
  - `verbose` property
  - `scan(timeout:)` method
  - `readCurrentReadings(from:)` method
  - `monitor(from:)` method (already documented)
- **Documentation style**:
  - Clear, concise descriptions of purpose and behavior
  - Parameter documentation with types and constraints
  - Return value descriptions
  - Error cases with specific conditions
  - Usage examples with code snippets
  - Important notes and caveats
- **Benefits**:
  - Better IDE autocomplete and inline help
  - Easier for other developers to use the library
  - Self-documenting code reduces need for external docs
  - Follows Swift DocC conventions for documentation generation
- **Reasoning**: Comprehensive documentation makes the library more accessible and professional. Following Apple's DocC style ensures compatibility with Swift documentation tools and provides excellent IDE integration.

### 2025-11-22 20:45 (Monitor Refactoring - Library API)

- **Refactored monitoring logic**: Moved from CLI to AranetKit library as reusable API
- **New library method**: `AranetClient.monitor(from:) -> AsyncStream<Result<AranetReading, Error>>`
- **Timer-based scheduling**: Replaced Task.sleep with proper Timer implementation
- **AsyncStream pattern**: Returns Result-wrapped readings for clean error handling
- **Accurate timing**: Uses device interval and ago values to schedule reads 3 seconds after each sensor update
- **No drift**: Recalculates delay based on actual sensor age, not accumulated time
- **Implementation details**:
  - `@MainActor` isolation for CoreBluetooth compatibility
  - Internal `monitoringLoop` method with CheckedContinuation wrapping Timer
  - Proper cancellation handling via Task.isCancelled checks
  - Adaptive interval scheduling based on device-reported intervals and age
- **CLI simplification**: Monitor command now simply iterates over the stream
- **Benefits**:
  - Monitoring logic reusable by other Swift projects importing AranetKit
  - Cleaner separation of concerns
  - Timer provides more accurate scheduling than Task.sleep
  - AsyncStream enables easy consumption via for-await loops
  - Eliminates timing drift by recalculating based on sensor age
- **Reasoning**: Library-level monitoring API enables broader reuse and follows Swift best practices for async sequences. Timer-based approach provides more reliable periodic execution on MainActor compared to Task.sleep. Using sensor age for scheduling prevents drift accumulation.

### 2025-11-22 20:30 (Monitor Command Implementation)

- **Added monitor command**: New CLI subcommand for continuous sensor monitoring
- **Implementation**: `AranetCli.swift` - Monitor struct with AsyncParsableCommand
- **Features**:
  - Initial sensor reading with device scan and connection
  - Smart scheduling based on device interval and ago values
  - Calculates next sensor update time and schedules first reading 15 seconds after
  - Continuous monitoring loop with periodic readings at interval + 15 seconds
  - Graceful cancellation handling (Ctrl+C)
  - Verbose mode support for debugging
- **Usage**: `aranetcli monitor <device> [--verbose]`
- **Technical details**:
  - Uses async/await with Task.sleep for scheduling
  - Handles CancellationError for clean exit
  - Displays timestamp with each reading
  - Adapts to device-reported intervals for subsequent readings
- **Reasoning**: Enables real-time monitoring of Aranet sensors without manual polling. The 15-second delay after expected updates ensures fresh data is available when reading. Smart scheduling uses device's own timing information for accurate synchronization.

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
- **Files updated**: `AranetClient.swift`, `AranetCli.swift`
- **Benefits**:
  - Improved code readability
  - Makes boolean comparisons explicit and unambiguous
  - Consistent style across the codebase
- **Reasoning**: Explicit boolean comparisons make code intent clearer and are easier to understand, especially for developers coming from languages where truthiness differs from Swift.

### 2025-11-22 18:45 (Library Package Architecture)

- **Created AranetKit library target**: Separated core Bluetooth functionality from CLI application
- **Package structure**:
  - `Sources/AranetKit/` - Library target with AranetClient and AranetTypes (reusable)
  - `Sources/AranetCli/` - Executable target with CLI and ProgressSpinner (application-specific)
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
- Updated Mission Statement to reflect aranetcli Swift CLI project
- Confirmed technology stack: Swift 6.2+, Swift Argument Parser, CoreBluetooth
- Established project as Swift reimplementation of Python aranet4 library
- Identified key features: sensor readings, historical logs, device settings, BLE scanning

### 2025-11-22 20:05 (Directory Naming - PascalCase)

- **Renamed directory**: Changed `Sources/aranetcli/` to `Sources/AranetCli/` to follow Swift naming conventions
- **Updated Package.swift**: Changed target name from `aranetcli` to `AranetCli` (executable name remains `aranetcli`)
- **Rationale**: Swift conventions use PascalCase for module/target names
- **Files updated**: Package.swift, AGENTS.md, README.md
- **Consistency**:
  - Package name: `AranetCli`
  - Target name: `AranetCli`
  - Directory: `Sources/AranetCli/`
  - Executable binary: `aranetcli` (lowercase for command-line use)
- **Reasoning**: Follows Swift Package Manager conventions where targets use PascalCase while executable products use lowercase for easier command-line usage

### 2025-11-22 20:00 (Project Naming Standardization)

- **Updated project name**: Changed all references from `aranetctl` to `aranetcli` throughout documentation
- **Rationale**: Align with Package.swift configuration where executable is named `aranetcli`
- **Files updated**: AGENTS.md references to project name, executable name, and directory structure
- **Consistency**: Package name `AranetCli`, executable `aranetcli`, directory `Sources/aranetcli/`
- **Reasoning**: Standardizing on `aranetcli` (CLI = Command Line Interface) provides clearer naming and matches the actual build artifacts and source structure

### 2025-10-05

- Initial AGENTS.md setup
- Established core coding standards and conventions
- Created agent-specific reference files
- Defined repository structure and governance principles
