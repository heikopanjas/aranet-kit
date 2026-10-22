# Project Instructions for AI Coding Agents

**Last updated:** 2026-10-22

<!-- {preamble} -->

# ⚠️ Before You Start

Run `/init-session` at the beginning of each new session, OR read this entire file before proceeding.

**DO NOT** make code changes or commits until you have done one of the above.

<!-- {mission} -->

## Mission Statement

**AranetKit** is a Swift library and **aranet-cli** a command-line tool for reading Aranet4, Aranet2, and Aranet Radiation Bluetooth LE sensors. Aranet Radon Plus is recognized but its readings are not parsed yet. It is a native Swift reimplementation of the Python `aranet4` library, offering async/await APIs and type-safe measurements without requiring device pairing.

Key features:

- `scan` for nearby Aranet devices
- `read` current measurements from one or more devices concurrently
- `monitor` one or more devices with updates timed to the device-reported interval
- `--json` mode on every subcommand for scripts and agents (data only, no progress output)
- `NotificationCenter` broadcasts (`aranetReadingDidUpdate`) for every monitored reading
- Swift Foundation `Measurement<Unit>` values, including custom radiation and radioactivity units
- CoreBluetooth fully encapsulated behind the `AranetDevice` value type

## Technology Stack

- **Language:** Swift 6.2+ (swift-tools-version 6.2), macOS 12+
- **Framework:** Swift Argument Parser (CLI), CoreBluetooth (Bluetooth LE), Foundation Units
- **Version Control:** Git (`develop` for development, `main` for releases)
- **Package Manager:** Swift Package Manager (SPM)
- **CI/CD:** GitHub Actions (`build.yml`, `lint.yml`, `release.yml`) on `macos-15`
- **License:** MIT (inherited from the Python implementation)

## Session Protocol

When starting a new session, read this entire file and confirm you have
understood the project instructions before proceeding. Summarize the project
purpose and key conventions briefly. Do not make changes until you have
confirmed your understanding.

<!-- {principles} -->

## Primary Instructions

- Avoid making assumptions. If you need additional context to accurately answer the user, ask the user for the missing information. Be specific about which context you need.
- Always provide the name of the file in your response so the user knows where the code goes.
- Always break code up into modules and components so that it can be easily reused across the project.
- All code you write MUST be fully optimized. ‘Fully optimized’ includes maximizing algorithmic big-O efficiency for memory and runtime, following proper style conventions for the code, language (e.g. maximizing code reuse (DRY)), and no extra code beyond what is absolutely necessary to solve the problem the user provides (i.e. no technical debt). If the code is not fully optimized, you will be fined $100.

### Working Together

This file (`AGENTS.md`) is the primary instructions file for AI coding assistants working on this project. Agent-specific instruction files (such as `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules`) reference this document, maintaining a single source of truth.

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
- Log every change in the "Recent Updates & Decisions" log in `UPDATES.md` with:
  - Date (with time if multiple updates per day)
  - Brief description
  - Reasoning for the change
- New log entries go directly below the changelog marker in `UPDATES.md`, newest first; load the `recent-updates` skill for the full rules
- Preserve the AGENTS.md structure: title header → timestamp → main instructions

## Best Practices

### When Updating This Repository

1. **Maintain Consistency**: Keep code style consistent across the codebase
2. **Test First**: Write tests before implementing features when applicable
3. **Document Changes**: Update documentation when changing functionality
4. **Code Review**: Before committing, check the change against the Development Guidelines below; it must build without warnings and pass `xcrun swift-format lint --configuration .swift-format --recursive --strict Sources` (the CI `lint` job); findings and the phased fix plan from the 2026-10-22 review live in `CODE_REVIEW.md`
5. **Date Changes**: Update the "Last updated" timestamp in this file when making changes
6. **Log Updates**: Add entries to the "Recent Updates & Decisions" log in `UPDATES.md`

### Development Guidelines

- Follow the `swift-coding-conventions` skill and the **Package Architecture Patterns** below
- Keep device and protocol logic in `AranetKit`; `AranetCli` only parses commands and presents results
- Parse BLE payloads according to **Aranet Device Data Formats** and expose physical quantities as described in **Swift Foundation Units**
- **CLI output**: every subcommand honors `GlobalOptions` (`--verbose`, `--json`). JSON payloads must stay deterministic; progress spinners and human text never go to JSON output
- Follow the **Release Process** for anything touching `.github/workflows/` or `Scripts/`

### Security & Safety

- Never include API keys, tokens, or credentials in code
- Always require explicit human confirmation before commits
- Maintain conventional commit message standards
- Keep change history transparent through commit messages
- Signing and notarization secrets (`APPLE_*`, `APPSTORE_CONNECT_*`) exist only as GitHub Actions secrets; never print or persist decoded credentials, and never expose them to pull-request validation or dry-run jobs
- Only the post-merge release job running trusted `main` content may sign and notarize

### Testing

- Testing framework: Swift Testing, run with `swift test`; load the `swift-testing-pro` skill before writing or reviewing tests
- Layout: `Tests/AranetKitTests/` and `Tests/AranetCliTests/` mirror `Sources/`, with shared fixtures in `Fixtures/`, test doubles in `Fakes/`, and tags in `Tags.swift`; the CLI suite uses `@testable import AranetCli`
- Tests first: add or update the test before the production change it covers
- Coverage: `Scripts/check-coverage.sh` runs the suites with code coverage and fails below `COVERAGE_THRESHOLD` (default set in the script and raised per `TEST_PLAN.md` milestone, ending at 100); region coverage is reported but not gated; the only excluded file is the CoreBluetooth delegate adapter, which needs real peripherals
- CI: `build.yml` runs the coverage script and a Thread Sanitizer job (`swift test --sanitize=thread`), the `release.yml` dry run runs `swift test`, and `lint.yml` lints `Tests` as well as `Sources`
- Integration: manual runs against real devices with `swift run aranet-cli <command> --verbose`; CoreBluetooth is not mocked at the framework level, the `BluetoothCentral` seam is faked instead (from milestone M3 of `TEST_PLAN.md`)

### Documentation

- Code comments: explain why, not what; keep them sparse
- API documentation: DocC `///` comments on every public declaration in `AranetKit`
- README updates: required whenever commands, flags, output formats, installation, or public API change
- Release notes: `CHANGELOG.md` (Keep a Changelog format) feeds the GitHub release notes via `Scripts/changelog-section.sh`; add a section for every version bump
- Decision log: maintained in `UPDATES.md` (see the `recent-updates` skill)

<!-- {languages} -->

## Swift Coding Standards

Load the `swift-coding-conventions` skill before writing, reviewing, or refactoring Swift code.
Load the `swift-build-commands` skill when building or running the project.

## Package Architecture Patterns

### Library Structure

**aranet-cli** follows Swift Package Manager best practices with clear separation between library and executable:

- **AranetKit** (library): Core Bluetooth client, data models, reusable components
- **AranetCli** (executable): CLI application, command handling, user interface

### Controller/Service Pattern

```swift
// Service: Stateless data fetching
public class AranetClient {
    func scan(timeout: TimeInterval) async throws -> [AranetDevice]
    func readCurrentReadings(from device: AranetDevice) async throws -> AranetReading
    func monitor(from device: AranetDevice) -> AsyncStream<Result<AranetReading, Error>>
}

// CLI: Command handling and presentation
@main
struct AranetCLI: AsyncParsableCommand {
    @Command var read: ReadCommand
    @Command var scan: ScanCommand
}
```

### Public API Surface

The library's public API uses only value types (`AranetDevice`, `AranetReading`). CoreBluetooth is fully encapsulated inside `AranetClient` -- consumers never need to `import CoreBluetooth`.

```swift
// AranetDevice abstracts CBPeripheral
public struct AranetDevice: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
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

### Concurrent Read Isolation

Each read operation gets its own `ReadOperation` instance keyed by peripheral UUID in `activeOperations: [UUID: ReadOperation]`. This prevents cross-device state corruption when reading from multiple peripherals simultaneously.

### Data Models

Follow standard Swift value type patterns:

```swift
public struct AranetReading: Sendable {
    public let deviceType: AranetDeviceType
    public let co2: UInt16?
    public let temperature: Measurement<UnitTemperature>?
    public let humidity: UInt8?
    // ...
}

public enum AranetDeviceType: UInt8, Sendable {
    case aranet4 = 0
    case aranet2 = 1
    // ...
}
```

## Swift Foundation Units

### Overview

AranetKit uses Swift Foundation's `Measurement<Unit>` types for all physical quantities. This provides type safety, automatic unit conversions, and better API semantics.

### Standard Foundation Units

The following measurements use built-in Foundation unit types:

- **Temperature**: `Measurement<UnitTemperature>` - stored in celsius
- **Pressure**: `Measurement<UnitPressure>` - stored in hectopascals

Example usage:

```swift
let reading = try await client.readCurrentReadings(from: device)

// Access value in native unit (Celsius)
let tempC = reading.temperature?.value

// Convert to different unit
if let tempF = reading.temperature?.converted(to: .fahrenheit) {
    print("Temperature: \(tempF.value)°F")
}
```

### Custom Unit Types

AranetKit defines custom `Dimension` subclasses for radiation and radioactivity measurements.

#### UnitRadiationDose

Measures ionizing radiation dose with base unit nanosieverts (nSv).

**Available units:**

- `.nanosieverts` (nSv) - base unit, coefficient 1.0
- `.microsieverts` (µSv) - coefficient 1000.0
- `.millisieverts` (mSv) - coefficient 1,000,000.0
- `.sieverts` (Sv) - coefficient 1,000,000,000.0

**Usage:**

```swift
// Radiation rate stored in nSv/h
let rateNsv = reading.radiationRate?.value

// Convert to microsieverts for display
if let rateMicroSv = reading.radiationRate?.converted(to: .microsieverts) {
    print("Dose rate: \(rateMicroSv.value) µSv/h")
}

// Cumulative dose
if let totalMsv = reading.radiationTotal?.converted(to: .millisieverts) {
    print("Total dose: \(totalMsv.value) mSv")
}
```

**Typical values:**

- Background radiation: 50-200 nSv/h (0.05-0.2 µSv/h)
- Annual effective dose limit (public): 1 mSv (1000 µSv)

#### UnitRadioactivity

Measures radon gas concentration with base unit becquerels per cubic meter (Bq/m³).

**Available units:**

- `.becquerelsPerCubicMeter` (Bq/m³) - base unit, SI standard
- `.picocuriesPerLiter` (pCi/L) - coefficient 37.0, common in USA

**Usage:**

```swift
// Radon concentration stored in Bq/m³
let radonBq = reading.radonConcentration?.value

// Convert to picocuries per liter
if let radonPci = reading.radonConcentration?.converted(to: .picocuriesPerLiter) {
    print("Radon: \(radonPci.value) pCi/L")
}
```

**Reference levels:**

- WHO action level: 100 Bq/m³
- EPA action level: 148 Bq/m³ (4 pCi/L)

### Primitive Values

The following properties remain as primitive types (not Measurements):

- `humidity: UInt8?` - percentage (0-100), dimensionless
- `battery: UInt8` - percentage (0-100), dimensionless
- `co2: UInt16?` - parts per million (ppm), dimensionless ratio
- `interval: UInt16?` - seconds, simple duration
- `ago: UInt16?` - seconds, simple duration
- `radiationDuration: UInt64?` - seconds, simple duration

**Rationale**: These are either dimensionless quantities (percentages, ratios) or simple time durations that don't benefit from the `Measurement` overhead.

### Data Format Documentation

When parsing raw BLE data, values are converted to their native units:

- Temperature: raw value / 20.0 → Celsius
- Pressure: raw value / 10.0 → hectopascals (hPa)
- Radiation rate: raw value or (raw value / 10.0) → nanosieverts per hour (nSv/h)
- Radiation total: raw value → nanosieverts (nSv)
- Radon concentration: raw value → becquerels per cubic meter (Bq/m³) (planned; Radon Plus payloads are not parsed yet)

## Aranet Device Data Formats

This section provides detailed byte-level documentation for all Aranet device data formats. All values are stored in little-endian (LE) byte order unless otherwise specified.

### Overview

Aranet devices use Bluetooth Low Energy (BLE) characteristics to transmit sensor data. The **detailed** characteristics (F0CD3001, F0CD3003) need no pairing; the **basic** ones (F0CD1503, F0CD1504) require pairing. All characteristics except F0CD1503 include interval and ago values.

| Characteristic | Devices | Payload size | Pairing | Notes |
| --- | --- | --- | --- | --- |
| F0CD3001 | Aranet4 | 13 bytes | No | Preferred for Aranet4 |
| F0CD1503 | Aranet4 | 9 bytes | Yes | No interval or ago |
| F0CD1504 | Aranet2, Aranet Radiation | 10 bytes (Aranet2), 28 bytes (Radiation) | Yes | Radiation rate stored as nSv/h × 10 |
| F0CD3003 | Aranet2, Aranet Radiation | Aranet2 assumed same as F0CD1504, 48 bytes (Radiation) | No | Radiation rate stored as nSv/h |

**Characteristic selection:** `AranetUUID.readingCharacteristicPriority` reads the first available characteristic in the order F0CD3001, F0CD3003, F0CD1504, F0CD1503.

**Device dispatch:** F0CD3001 and F0CD1503 are always parsed as Aranet4. For F0CD1504 and F0CD3003, byte 0 is the on-wire device type:

| Byte 0 | Device | Parser behavior |
| --- | --- | --- |
| `0x02` | Aranet2 | Parsed with the F0CD1504 layout (unverified, see below) |
| `0x03` | Aranet Radon Plus | Not implemented; throws `AranetError.invalidData` |
| `0x04` | Aranet Radiation | 28 bytes → rate ÷ 10; 48+ bytes → rate as-is; any other length throws `AranetError.invalidData` |

**Note:** these on-wire device type bytes are unrelated to the raw values of the `AranetDeviceType` enum (`aranet4 = 0`, `aranet2 = 1`, `aranetRadiation = 2`, `aranetRadon = 3`). Never convert one into the other with `init(rawValue:)`.

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

#### F0CD1503 - Basic Current Readings (9 bytes)

**Characteristic UUID:** `F0CD1503-95DA-4F4B-9AC8-AA55D312AF0C`
**Python struct format:** `<HHHBBB`
**Total size:** 9 bytes
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

> **Unverified:** this layout has not been confirmed with a hex dump from a real Aranet2. The Python struct format `<HHHBHHB` describes 12 bytes (a 2-byte first field, interval at bytes 2-3, and a 2-byte humidity), which contradicts the 10-byte table below. The parser follows the table. Capture a payload from a real device before relying on or changing this section.

**Characteristic UUID:** `F0CD1504-95DA-4F4B-9AC8-AA55D312AF0C`
**Python struct format:** `<HHHBHHB` (conflicts with the table, see above)
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
let statusHumidity = AranetStatus(rawValue: statusRaw & 0b0011)
let statusTemperature = AranetStatus(rawValue: (statusRaw & 0b1100) >> 2)
```

**Note:** the parser currently reads and discards the status byte; `AranetReading` has no field for the Aranet2 humidity and temperature status bits.

---

### Aranet Radiation Device Formats

#### F0CD3003 - Detailed Current Readings (48 bytes)

**Characteristic UUID:** `F0CD3003-95DA-4F4B-9AC8-AA55D312AF0C`
**Python struct format:** `<HHHBIQQB` (for first 28 bytes)
**Total size:** 48 bytes
**Pairing required:** No

The F0CD3003 characteristic returns 48 bytes of data for Aranet Radiation devices. The format differs from F0CD1504 (28 bytes) and requires specific byte positioning.

**Byte Structure (48 bytes total):**

The first 28 bytes follow the same `<HHHBIQQB` format as F0CD1504:

```
Byte 0:     Device type (0x04 = Aranet Radiation)
Byte 1:     Unknown, not decoded (Python unpacks bytes 0-1 together as value[0])
Bytes 2-3:  Interval (UInt16 LE) - measurement interval in seconds (value[1] in Python)
Bytes 4-5:  Ago (UInt16 LE) - seconds since last update (value[2] in Python)
Byte 6:     Battery (UInt8) - battery level percentage (0-100) (value[3] in Python)
Bytes 7-10: Rate (UInt32 LE) - radiation dose rate in nSv/h (NOT multiplied by 10) (value[4] in Python)
Bytes 11-18: Total (UInt64 LE) - cumulative radiation dose in nSv (value[5] in Python)
Bytes 19-26: Duration (UInt64 LE) - measurement duration in seconds (value[6] in Python)
Byte 27:     Status (UInt8) - status display color (value[7] in Python, unused there)
             Encoding differs from Aranet4: 0x05=Green, 0x0A=Yellow, 0x0B=Red
Bytes 28-35: Total dose (UInt64 LE) - cumulative dose in microsieverts (uSv)
             Equals floor(total_nSv / 1000), lower-resolution duplicate of bytes 11-18
Bytes 36-43: Realtime duration (UInt64 LE) - elapsed time in seconds, 60s granularity
             Equals floor((duration + ago) / 60) * 60, continuously updated unlike bytes 19-26
Bytes 44-47: Reserved (zero)
```

**Note:** The Python struct format `<HHHBIQQB` unpacks bytes 0-27, where the first `H` covers the device type (byte 0) and the undecoded byte 1. The Swift parser reads byte 0 for device dispatch, then skips to offset 2 and reads interval from bytes 2-3 and ago from bytes 4-5.

**Important Notes:**

- **Rate format**: For F0CD3003, the rate is stored as nSv/h directly (NOT multiplied by 10 like F0CD1504)
- **Data model**: `radiationRate` in `AranetReading` is stored in nSv/h; `formatOutput()` converts to µSv/h for display
- **Duration**: Represents total time the sensor has been measuring since last reset (typically 8+ days for long-running sensors)
- **Total dose**: Cumulative dose since last counter reset, stored in nanosieverts (nSv)
- **Status**: Byte 27 encodes the status display color using a different scheme than Aranet4 (0x05=Green, 0x0A=Yellow, 0x0B=Red). The Python library reads this byte but does not use it.
- **Extended data (bytes 28-47)**: Contains lower-resolution duplicates -- total dose in µSv (bytes 28-35) and a real-time duration counter with 60-second granularity (bytes 36-43). Bytes 44-47 are reserved (zero). The Python library ignores all 20 bytes.

#### F0CD1504 - Radiation Current Readings (28 bytes)

Aranet Radiation also answers on F0CD1504 with a 28-byte payload. Bytes 0-27 use the same layout as F0CD3003 above, with one difference: the rate at bytes 7-10 is stored as nSv/h × 10, so the parser divides it by 10. Bytes 28-47 are absent. Reading F0CD1504 requires pairing.

**Comparison:**

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

### Aranet Radon Plus Device Format

> **Not implemented, unverified:** Aranet Radon Plus reports device type `0x03` in byte 0 of F0CD1504/F0CD3003. The payload layout is undocumented here and the parser throws `AranetError.invalidData` for it. Capture a hex dump from a real device and document the layout before implementing parsing.

## Project Build Commands

Generic SwiftPM commands live in the `swift-build-commands` skill. These are the project-specific ones:

```bash
# Run the CLI from source
swift run aranet-cli scan
swift run aranet-cli read <device> --verbose

# Format code with the Xcode-bundled swift-format
xcrun swift-format format --configuration .swift-format --in-place --recursive Sources

# Lint code; --strict makes findings fail CI
xcrun swift-format lint --configuration .swift-format --recursive --strict Sources

# Verify the arm64 release artifact
Scripts/verify-binary-architecture.sh "$(swift build -c release --show-bin-path)/aranet-cli"
```

**Important**: Always use debug builds (`swift build`) during development. Debug builds compile faster and include debugging symbols. Only use release builds (`swift build -c release`) for final testing or deployment. CI builds are Apple Silicon `arm64` only; do not add universal (`--arch x86_64`) builds.

<!-- {integration} -->

## Release Process

### Workflow and Version Gate

- Direct pushes to `main` are disabled. `.github/workflows/release.yml` validates pull
  requests targeting `main` and publishes releases from the resulting push to `main`.
- Open, synchronized, reopened, labeled, and unlabeled pull requests run strict linting,
  release metadata validation, and an unsigned arm64 packaging dry run.
- The merge commit pushed to `main` runs the signed and notarized release job and creates
  the `v<toolVersion>` tag and GitHub release. The job checks out the exact pushed SHA so
  its Actions branch and source provenance both identify `main`.
- Manual releases are permitted only when `workflow_dispatch` is run from `main`; release
  content write permission is scoped to the publication job.
- Production publication runs are serialized and never cancel an in-progress signing or
  notarization job; updated checks for the same open pull request remain cancellable.
- `Sources/AranetCli/AranetCli.swift` and the newest released section in `CHANGELOG.md`
  must contain the same semantic version. The release fails if that tag already exists.
- Apply the `skip-release` label to changes that do not require a version bump. The
  validation job reports success while packaging and publishing are skipped. Pull-request
  checks read the event labels; the subsequent `main` push resolves the merged pull request
  associated with its commit and honors the same label. A `main` push without an associated
  merged pull request fails validation rather than publishing.
- `lint` and `validate` must be required status checks in `main` branch protection.

### Architecture and Artifacts

- All CI binaries are Apple Silicon `arm64`; every build verifies the Mach-O architecture
  with `Scripts/verify-binary-architecture.sh`.
- Release assets are `aranet-cli-<version>-macos-arm64.tar.gz` and `SHA256SUMS.txt`.
- The pre-built executable supports Apple Silicon Macs only. Intel users build from source.
- `AranetKit` is distributed as source through the release tag. Do not publish an
  `.xcframework` or DocC archive unless this decision changes.
- `Scripts/extract-version.sh`, `Scripts/changelog-section.sh`,
  `Scripts/verify-version.sh`, and `Scripts/package-release.sh` are the shared release
  implementation. Keep workflows DRY by updating these helpers rather than duplicating logic.

### Signing and Notarization

- Sign with Developer ID Application, hardened runtime, and a secure timestamp.
- Authenticate `notarytool` with an App Store Connect API Team Key. Individual API keys
  cannot notarize Developer ID software.
- A bare Mach-O executable cannot hold a stapled notarization ticket. The release is
  notarized but not stapled; Gatekeeper performs an online ticket lookup.
- Required GitHub Actions repository secrets:
  - `APPLE_CERTIFICATE_P12_BASE64`
  - `APPLE_CERTIFICATE_PASSWORD`
  - `APPLE_SIGNING_IDENTITY`
  - `APPSTORE_CONNECT_KEY_ID`
  - `APPSTORE_CONNECT_ISSUER_ID`
  - `APPSTORE_CONNECT_KEY_P8_BASE64`
- Never print or persist decoded credentials. The workflow uses an ephemeral keychain and
  removes the decoded `.p12` and `.p8` files in an unconditional cleanup step.
- Never expose signing or notarization secrets to pull-request validation or dry-run jobs.
  Secrets are available only to the post-merge release job running trusted `main` content.
- Team keys do not expire but can be revoked. Rotate one by revoking it, generating a new
  Team Key, and replacing the key ID and base64 `.p8` secrets. Developer ID certificates
  expire and must be re-exported with their private key before expiry.

### Release Helpers

```bash
# Print the canonical CLI version
Scripts/extract-version.sh

# Verify toolVersion and CHANGELOG agree
Scripts/verify-version.sh

# Extract one release-notes section
Scripts/changelog-section.sh 3.5.1

# Package an already-built signed executable
Scripts/package-release.sh 3.5.1 /path/to/aranet-cli
```

## Commit Protocol

- **NEVER commit automatically** — always wait for explicit user confirmation
- Stage changes, write a conventional commits message (max 50-char subject, 72-char body lines), then commit
- Load the `git-workflow` skill for the full message format, character limits, and examples before committing
- Never add co-authorship trailers or any attribution naming an AI coding agent to commit messages

## Recent Updates & Decisions

Project decisions and notable changes are logged in `UPDATES.md`, below its changelog marker. The log is append-only: add new entries at the top, never edit or delete existing ones, and keep the "Last updated" timestamp in `AGENTS.md` in sync. Load the `recent-updates` skill for the entry format and full rules.

## Semantic Versioning

Automatically bump the project version after every code change and include it in the same commit. Load the `semantic-versioning` skill for the full PATCH/MINOR/MAJOR decision rules.
