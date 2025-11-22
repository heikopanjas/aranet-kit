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

## Swift Coding Conventions

*Last updated: November 22, 2025*

This document defines project-specific coding conventions for aranetctl. Standard Swift conventions (naming, syntax, etc.) are assumed. Code formatting and style are managed by swift-format configuration.

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

**aranetctl** follows Swift Package Manager best practices with clear separation between library and executable:

- **AranetKit** (library): Core Bluetooth client, data models, reusable components
- **aranetctl** (executable): CLI application, command handling, user interface

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
