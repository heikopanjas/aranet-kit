# Test Plan: 100% Coverage for AranetKit and aranet-cli

**Baseline:** `develop` at `3851dca` (`toolVersion` 3.5.3), branch `feature/code-review`
**Companion:** `CODE_REVIEW.md` (findings referenced by ID below)
**Framework:** Swift Testing (Swift 6.2 toolchain), coverage via `swift test --enable-code-coverage` and `llvm-cov`

## Status (2026-10-22)

All milestones are implemented on `feature/code-review`; `Scripts/check-coverage.sh` gates at 100% line coverage of `Sources/` with `CoreBluetoothCentral.swift` as the single exclusion.

| Milestone | Commit | Result |
| --- | --- | --- |
| M0 infrastructure | `test: add swift testing targets and coverage gate` | two test targets, coverage script, CI jobs |
| M1 pure parsing | `refactor(kit): extract bounds checked payload parser` | parser, reader, hex dump suites |
| M2 monitoring | `refactor(kit)!: stop monitoring when the stream ends` | `ReadingMonitor`, `MonitorSchedule` suites |
| M3 client over the seam | `refactor(kit)!: isolate the client on the main actor` | session, registry, scan, read, monitor suites over `FakeBluetoothCentral` |
| M4 CLI | `refactor(cli)!: route commands through an environment`, `test(cli): cover every command path` | every command path, exit tests, spinner, JSON writer |
| M5 gate | `test: gate line coverage at 100 percent` | 240+ tests, Thread Sanitizer green, gate at 100 |

Lessons recorded while landing the plan:

- Timer tasks the client starts (`Task { try await sleep(...) }`) run after the Bluetooth command that precedes them is recorded, so tests wait for the fake sleeper (`SleepGate.waiting` or `requestedDelays`) before releasing it; `SleepGate` records an issue when a release finds nobody sleeping.
- Releasing an `AsyncStream` cancels its producer through `onTermination`, so a monitor test keeps its iterator alive until the loop has ended.
- Exit tests cannot run under Thread Sanitizer (the child process produces no output); `ExitTestSupport` disables them there.
- The two hardware-only behaviors planned as `withKnownIssue` (Aranet2 pairing detection, `ago > interval`) turned out to be testable through the fakes and are covered without known-issue markers.

## Context

The package has no test target and CI runs no tests. The code review showed why tests are hard today: payload parsing is a private method on the Bluetooth-bound client, the monitoring loop mixes scheduling with CoreBluetooth reads, and the CLI constructs `AranetClient` and writes to stdout directly.

Decisions taken with the maintainer:

- Scope: the AranetKit library and `aranet-cli` only (senor-particle has its own plan).
- Hardware-bound code gets protocol seams and fakes rather than coverage exclusions.
- Tests drive the refactors: each milestone introduces only the seam it needs, pulling in the matching `CODE_REVIEW.md` items (A1, A2, K1, K2, K3, K8, C8, C9, C10) as it goes.

Target: 100% line coverage of `Sources/AranetKit` and `Sources/AranetCli`, enforced in CI.

## Definition of done

- `Scripts/check-coverage.sh` exits non-zero when line coverage of `Sources/**` is below the threshold; the threshold ends at `100`.
- Region (branch) coverage is reported in the CI log but not gated; it is reviewed at M5 for dead `??` fallbacks and untaken `else` paths.
- Exactly one file is excluded, by name, with the reason in the script: `Sources/AranetKit/Bluetooth/CoreBluetoothCentral.swift`, the delegate-forwarding adapter whose methods take `CBPeripheral`, `CBService`, and `CBCharacteristic` arguments that cannot be instantiated in a test process, and whose `CBCentralManager` construction would trigger the Bluetooth permission prompt on a CI runner. It also hosts the public `AranetClient.init()` and the `AranetClient.makeLive` factory, the only other lines that construct a CoreBluetooth object. It stays pure forwarding and is verified by the manual hardware checklist. Everything else, including every line of `AranetClient`, is covered through the `BluetoothCentral` seam.
- Tests pass under Thread Sanitizer (`swift test -Xswiftc -sanitize=thread`) in a separate CI job.
- `xcrun swift-format lint --strict` covers `Tests` as well as `Sources`.

## Architecture seams

Each seam is introduced by the milestone that first needs it.

### S1. Pure parsing (M1, review A1)

- `Sources/AranetKit/Parsing/ByteReader.swift`: `struct ByteReader` with throwing `uint8()`, `uint16LE()`, `uint32LE()`, `uint64LE()`, `skip(_:)`; throws `AranetError.invalidData` on overrun.
- `Sources/AranetKit/Parsing/AranetPayloadParser.swift`: `enum AranetPayloadParser { static func reading(from: Data, characteristic: CBUUID?, name: String, version: String) throws -> AranetReading }`. Moves the bodies of `parseReading` (`AranetClient.swift:941-1130`) branch by branch; a `WireDeviceType` enum replaces the `== 4/2/3` literals; payload lengths become named constants.
- `AranetReading: Equatable` so tests compare whole readings.
- Hex-dump helpers (`printHexDump`, `aranet4Fields`, `radiationFields`, `AranetClient.swift:883-937`) move to `Sources/AranetKit/Diagnostics/PayloadHexDump.swift` as a pure `static func lines(for: Data, fields:) -> [String]` so the formatting is testable and the logger only emits the lines.

### S2. Monitoring without Bluetooth (M2, review A2, C1, K2)

- `Sources/AranetKit/Monitoring/MonitorSchedule.swift`: `struct MonitorSchedule { static let readMargin: TimeInterval = 3; static func nextDelay(interval: TimeInterval, ago: UInt16?) -> TimeInterval }` with the negative-delay clamp.
- `Sources/AranetKit/Monitoring/ReadingMonitor.swift`: `struct ReadingMonitor` taking `read: @Sendable (AranetDevice) async throws -> AranetReading`, `sleep: @Sendable (TimeInterval) async throws -> Void`, and `publish: @Sendable (AranetDevice, AranetReading) -> Void`; exposes `func run(for: AranetDevice, into: AsyncStream<Result<AranetReading, any Error>>.Continuation) async`.
- `AranetClient.monitor(from:)` becomes `AsyncStream.makeStream(of:)` plus `onTermination` cancelling the task, composing `ReadingMonitor` with `readCurrentReadings` and `Task.sleep`.

### S3. Bluetooth seam (M3, review K1, K3, K5, C2, C3, C4, C7)

- `Sources/AranetKit/Bluetooth/BluetoothCentral.swift`:

  ```swift
  @MainActor
  protocol BluetoothCentral: AnyObject {
      var state: CBManagerState { get }
      var events: AsyncStream<BluetoothEvent> { get }
      func scanForPeripherals(services: [CBUUID]) -> Void
      func stopScan() -> Void
      func retrievePeripherals(identifiers: [UUID]) -> [PeripheralInfo]
      func connect(_ peripheral: UUID) -> Void
      func cancelConnection(_ peripheral: UUID) -> Void
      func discoverServices(_ peripheral: UUID) -> Void
      func discoverCharacteristics(peripheral: UUID, service: CBUUID) -> Void
      func readValue(peripheral: UUID, characteristic: CBUUID) -> Void
  }
  ```

- `Sources/AranetKit/Bluetooth/BluetoothEvent.swift`: `enum BluetoothEvent: Sendable` with cases `stateChanged(CBManagerState)`, `discovered(PeripheralInfo, rssi: Int)`, `connected(UUID)`, `connectFailed(UUID, (any Error)?)`, `disconnected(UUID, (any Error)?)`, `servicesDiscovered(UUID, [CBUUID], (any Error)?)`, `characteristicsDiscovered(UUID, service: CBUUID, [CBUUID], (any Error)?)`, `valueUpdated(UUID, characteristic: CBUUID, Data?, (any Error)?)`; plus `struct PeripheralInfo: Sendable, Equatable { let id: UUID; let name: String? }`.
- `Sources/AranetKit/Bluetooth/CoreBluetoothCentral.swift`: the only file that handles CoreBluetooth objects. Owns `CBCentralManager(queue: .main)`, a `[UUID: CBPeripheral]` map, and the two delegate extensions, each method a one-line `continuation.yield(…)` after extracting identifiers, UUIDs, and data. This is the excluded file.
- `Sources/AranetKit/Client/ReadSession.swift`: `struct ReadSession` state machine replacing `ReadOperation` (`AranetClient.swift:172-188`) and the delegate decision logic (`:654-865`). `mutating func handle(_ event: BluetoothEvent) -> [ReadCommand]` where `enum ReadCommand { case discoverServices; case discoverCharacteristics(CBUUID); case read(CBUUID); case disconnect; case complete(Data, name: String, version: String); case fail(AranetError) }`. Pure and exhaustively testable: pending reads, characteristic priority, encryption-error counting (C3), no-reading-characteristic failure (C4), error-path completion (C7), disconnect mid-read (C2).
- `Sources/AranetKit/Client/WaiterRegistry.swift`: `struct WaiterRegistry<Value>` holding `[CheckedContinuation<Value, any Error>]` with `resumeAll(returning:)` and `resumeAll(throwing:)`; used for Bluetooth-ready waiters and scan waiters (K3).
- `AranetClient` becomes `@MainActor public final class AranetClient: NSObject` with `init(central: any BluetoothCentral = CoreBluetoothCentral(), readTimeout: TimeInterval = 30, pairingCheckDelay: TimeInterval = 5, sleep: …)`. It consumes `central.events` in one task and routes them to `ReadSession`s keyed by peripheral id. `verbose` prints become log calls (K8) through `Sources/AranetKit/Diagnostics/AranetLog.swift` (`enum AranetLog { static var sink: @Sendable (String) -> Void }`, defaulting to `os.Logger`; tests capture lines).
- Test double: `Tests/AranetKitTests/Fakes/FakeBluetoothCentral.swift` records commands and lets tests push events.

### S4. CLI seams (M4, review C8, C9, C10, K10)

- `Sources/AranetCli/CliEnvironment.swift`: `struct CliEnvironment: Sendable` with `makeClient`, `stdout`, `stderr`, `isTerminal`, `now`, `arguments`, `scanTimeout`, and an injectable interrupt stream; `@TaskLocal static var current = CliEnvironment.live`.
- `Sources/AranetKit/Client/SensorClient.swift`: `@MainActor protocol SensorClient: AnyObject` covering `verbose`, `scan(timeout:)`, `readCurrentReadings(from:)`, `monitor(from:)`; `extension AranetClient: SensorClient {}`. This is also the seam senor-particle's plan wants.
- `ProgressSpinner(output:)`, `JsonOutput` writes through `CliEnvironment.current.stdout`, every `print` in the commands routes through the environment.
- `AranetCliMain.exit(withError:)` (`AranetCli.swift:304-322`) splits into a pure `static func exitPlan(for: any Error, jsonRequested: Bool) -> ExitPlan` plus a two-line `Never` wrapper covered by a Swift Testing exit test (`#expect(processExitsWith:)`).
- The `Monitor` command reads the interrupt stream from the environment so the Ctrl+C path is testable without sending signals.

## Test target layout

```text
Package.swift                      + testTarget AranetKitTests (depends on AranetKit)
                                   + testTarget AranetCliTests (depends on AranetCli, @testable import)
Tests/AranetKitTests/
  Fixtures/Payloads.swift          named Data constants per characteristic and device, from the AGENTS.md byte tables
  Fixtures/Readings.swift          AranetReading fixtures per device type
  Fakes/FakeBluetoothCentral.swift
  Fakes/RecordingLog.swift
  Parsing/ByteReaderTests.swift
  Parsing/AranetPayloadParserTests.swift
  Diagnostics/PayloadHexDumpTests.swift
  Monitoring/MonitorScheduleTests.swift
  Monitoring/ReadingMonitorTests.swift
  Client/ReadSessionTests.swift
  Client/WaiterRegistryTests.swift
  Client/AranetClientScanTests.swift
  Client/AranetClientReadTests.swift
  Client/AranetClientMonitorTests.swift
  Types/AranetDeviceTypeTests.swift
  Types/AranetStatusColorTests.swift
  Types/AranetStatusTests.swift
  Types/AranetReadingTests.swift
  Units/UnitRadiationDoseTests.swift
  Units/UnitRadioactivityTests.swift
  AranetErrorTests.swift
  AranetNotificationsTests.swift
  Tags.swift                       .parsing .units .monitoring .bluetooth .cli
Tests/AranetCliTests/
  Fakes/FakeSensorClient.swift
  Fakes/CapturedOutput.swift
  CliEnvironmentTrait.swift        TestScoping trait that installs a fake CliEnvironment through the task-local
  GlobalOptionsTests.swift
  DeviceMatchingTests.swift
  TerminalOutputTests.swift
  JsonOutputTests.swift
  ScanCommandTests.swift
  ReadCommandTests.swift
  MonitorCommandTests.swift
  AranetCliMainTests.swift         exit tests
  ProgressSpinnerTests.swift
Scripts/check-coverage.sh
```

The folder structure mirrors `Sources` once the one-type-per-file split (review A3) lands in the same milestone as each file's tests.

## Test conventions

From the `swift-testing-pro` skill: suites are `struct`s; `@Suite` only to attach tags; `init()` for setup; `#expect(x == false)`, never `!x`; `#require` for optionals; parameterized tests with `zip` for pairwise cases; `confirmation()` for notifications and callbacks; no `Task.sleep` or timing in tests; `@MainActor` on suites that touch `AranetClient`; `withKnownIssue` for the two hardware-only behaviors until confirmed (Aranet2 pairing detection, `ago > interval`); `CustomTestStringConvertible` on `AranetError` and `BluetoothEvent` in the test target only; `.timeLimit(.minutes(1))` on the client suites.

## Milestones

Each milestone: tests first, then the smallest production change that makes them pass, then the coverage threshold raised in `Scripts/check-coverage.sh`. Each code-changing commit carries its `toolVersion` bump and `CHANGELOG.md` section (`Scripts/verify-version.sh` enforces this). Commits need explicit confirmation per the commit protocol.

### M0: Infrastructure (gate: report only)

- `Package.swift`: two test targets. Decide the platform floor now (review D4); the fake `sleep` seam makes the plan work on either, recommended `.macOS(.v13)`.
- `Scripts/check-coverage.sh`: runs `swift test --enable-code-coverage`, reads `$(swift test --show-codecov-path)` (the `llvm-cov export` JSON), computes line coverage over files under `Sources/`, prints a per-file table (lines, regions), excludes the one adapter file, and compares with `COVERAGE_THRESHOLD` (default in the script, overridable). Python 3 run with `-I`, or `jq`; no third-party tools.
- `.github/workflows/build.yml`: `swift test` plus the coverage script after the debug build; a new `tsan` job; `lint.yml` lints `Tests` too; the `validate` job in `release.yml` runs `swift test`.
- First suites that need no seams: `Units/*`, `Types/*`, `AranetErrorTests` (description non-empty per case), `DeviceMatchingTests`, `TerminalOutputTests`, `JsonOutputTests` (encoding only).
- `AGENTS.md`: Testing section rewritten (framework, layout, coverage gate, how to run); `UPDATES.md` entry. Version 3.5.4.

### M1: Pure parsing (gate at least 45%)

- S1 seams. `AranetPayloadParserTests` parameterized over the fixtures: Aranet4 at 13, 9, 11, 12, and 8 bytes; radiation at 28 (rate ÷ 10), 48 (rate as-is), 30, and 47 bytes; Aranet2 at 10 and 9 bytes; wire type 3 and an unknown wire type; both status mapping tables; little-endian asymmetry; `UInt16.max` values; name and version pass-through; `nil` characteristic treated as Aranet4. `ByteReaderTests`: every width at the exact end, one past the end, offset arithmetic. `PayloadHexDumpTests`: field clamping, value assembly, padding.
- `AranetClient.completeReading` calls the parser; `parseReading` is removed.

### M2: Monitoring (gate at least 65%)

- S2 seams, `AranetReading: Equatable`. `MonitorScheduleTests`: normal case, `ago == nil`, `ago > interval` clamp, interval change. `ReadingMonitorTests`: initial read failure finishes with `.failure`; readings yield in order; `interval == nil` yields `.invalidData`; consumer cancellation ends the producer within one fake `sleep` (the fake suspends on a continuation the test controls and records cancellation); one `aranetReadingDidUpdate` per reading via `confirmation(expectedCount:)`; `AranetNotificationsTests` for key names and `receivedAt`.
- `monitor(from:)` rewritten on `makeStream` with `onTermination`.

### M3: Client over the Bluetooth seam (gate at least 95%)

- S3 seams; `@MainActor final class AranetClient`; `@unchecked Sendable` removed; `verbose` prints become `AranetLog` calls.
- `ReadSessionTests`: full table of event sequences to commands (happy path on F0CD3001; priority fallback to F0CD3003, F0CD1504, F0CD1503; name and revision reads; encryption error counting on both the ATT error and nil-value paths; missing reading characteristic fails with `.readFailed` at once; error in characteristic discovery for the last service; disconnect mid-read; late events after completion ignored).
- `WaiterRegistryTests`: resume all returning and throwing, empty registry no-op, continuations consumed exactly once.
- `AranetClientScanTests`: powered-on immediate scan; waits for `.poweredOn`; `.unauthorized`, `.unsupported`, `.poweredOff` throw the matching error; ready timeout (fake sleep) throws `.bluetoothUnavailable`; two concurrent scans both return the same list (K3); duplicate discoveries deduplicated; cancellation stops the scan (K4); weak-self paths exercised by releasing the client mid-scan.
- `AranetClientReadTests`: unknown device throws `.deviceNotFound`; `retrievePeripherals` fallback (C6, if adopted); already-connected skips connect; connect failure; pairing watchdog at 5 s via fake sleep; 30 s timeout; the watchdog from read one does not fail read two (K5); duplicate read throws `.operationInProgress`; Bluetooth going off fails all operations; cancellation disconnects.
- `AranetClientMonitorTests`: end to end with the fake central feeding two readings, then consumer cancel, then no further `connect` commands recorded.
- `AranetLog` capture asserts that every former `verbose` branch produces a line. Each `if verbose` block becomes one unconditional debug log call, which is what makes those lines coverable.

### M4: CLI (gate 100% of `Sources/AranetCli`, overall at least 99%)

- S4 seams; file split per review A3; `CliEnvironmentTrait`.
- `GlobalOptionsTests` (json, verbose, spinner, status-text matrix, parameterized over the four flag combinations and the `--json` position), `ScanCommandTests` (found, none, error; JSON vs text; spinner on and off by `isTerminal`), `ReadCommandTests` (partial failures, not-found names, exit code, JSON array), `MonitorCommandTests` (readings streamed as newline-delimited JSON, failure policy, injected interrupt prints "Monitoring stopped." and exits with `ExitCode.success`), `AranetCliMainTests` (exit tests for help, version, parse error in JSON mode, runtime error in JSON mode), `ProgressSpinnerTests` (frames cycle, start and stop sequences captured, no output when not a terminal).

### M5: Close to 100% and harden (gate 100%)

- Region report review: remove unreachable branches (the duplicate `invalidData` branches at `AranetClient.swift:1073-1078` collapse into the `WireDeviceType` switch; the `try?` paths in `JsonOutput` become real error handling, C10) or add the test that reaches them.
- Thread Sanitizer job green; `withKnownIssue` entries re-checked on hardware and either removed or kept with `isIntermittent: false`.
- `Scripts/check-coverage.sh` threshold set to `100`; `AGENTS.md` records the gate, the single exclusion and why, and the tests-first rule; `CHANGELOG.md` 4.0.0 section (M3 changes public isolation and `monitor` semantics; see review D5).

## Per-file coverage map

| Source (after split) | Covered by | Notes |
| --- | --- | --- |
| `Parsing/ByteReader.swift` | `ByteReaderTests` | boundaries per width |
| `Parsing/AranetPayloadParser.swift` | `AranetPayloadParserTests` | every branch, including all `invalidData` paths |
| `Diagnostics/PayloadHexDump.swift`, `AranetLog.swift` | `PayloadHexDumpTests`, client suites via `RecordingLog` | |
| `Monitoring/MonitorSchedule.swift`, `ReadingMonitor.swift` | `MonitorScheduleTests`, `ReadingMonitorTests` | fake read and sleep |
| `Client/ReadSession.swift`, `WaiterRegistry.swift`, `SensorClient.swift` | `ReadSessionTests`, `WaiterRegistryTests` | pure |
| `Client/AranetClient.swift` | `AranetClientScanTests`, `AranetClientReadTests`, `AranetClientMonitorTests` | through `FakeBluetoothCentral` |
| `Bluetooth/BluetoothCentral.swift`, `BluetoothEvent.swift` | compiled into every client test | protocol and enum, trivially covered |
| `Bluetooth/CoreBluetoothCentral.swift` | excluded, manual hardware checklist | forwarding only, under 80 lines |
| `AranetUUID.swift`, `AranetError.swift`, `AranetNotifications.swift`, `Types/*`, `Units/*` | dedicated suites | `AranetError` gains `LocalizedError` (C5) and its test |
| `AranetCli/*` | `AranetCliTests` | via the `CliEnvironment` task-local |

## Reuse

- Fixture bytes: the byte tables in `AGENTS.md` ("Aranet Device Data Formats") are the source of truth for `Fixtures/Payloads.swift`; each fixture carries a comment naming its table.
- Logic to move, not rewrite: `parseReading` (`AranetClient.swift:941-1130`), the delegate decision logic (`:654-865`), `monitoringLoop` (`:455-516`), `match(queries:)` (`AranetCli.swift:141-162`), `formatOutput` (`:97-136`), `JsonReading.init` (`JsonOutput.swift:56-81`).
- Release helpers: `Scripts/verify-version.sh` and `Scripts/changelog-section.sh` already gate version and changelog agreement; `check-coverage.sh` follows their shape (`set -euo pipefail`, `ROOT_DIR`).
- CI shape: `lint.yml` is a reusable workflow; add `coverage.yml` the same way and call it from `build.yml` and `release.yml`.

## Verification

```bash
# From the repository root on a Mac with the Swift 6.2 toolchain
swift build
swift test                                          # all suites green
Scripts/check-coverage.sh                           # per-file table, exits 0 at the current threshold
COVERAGE_THRESHOLD=100 Scripts/check-coverage.sh    # the M5 gate
swift test -Xswiftc -sanitize=thread
xcrun swift-format lint --configuration .swift-format --recursive --strict Sources Tests
swift build -c release && Scripts/verify-binary-architecture.sh "$(swift build -c release --show-bin-path)/aranet-cli"
Scripts/verify-version.sh

# Hardware checklist for the excluded adapter (manual, once per milestone that touches it)
swift run aranet-cli scan --verbose
swift run aranet-cli read <device> --verbose
swift run aranet-cli monitor <device> --verbose     # then Ctrl+C, confirm no further reads
```

CI proof: `build.yml` shows the coverage table and the gate step passing; the `tsan` job is green; the `release.yml` validate job runs the tests.

## Assumptions and open points

- The single excluded file is the only deviation from literal 100%. If zero exclusions are required, the alternative is instantiating `CBPeripheral` through the Objective-C runtime in tests, which is fragile and not recommended.
- Exit tests require Swift Testing from the Swift 6.2 toolchain, which CI already pins.
- `@testable import AranetCli` of an executable target requires building tests with the Xcode toolchain, which `macos-15` provides; SwiftPM has supported it since 5.5.
- The platform floor (review D4) and the release shape (review D5) are decided at M0 and M5 respectively; the plan works either way.
- The plan was written in an environment without a Swift toolchain. The first `swift test` runs on the maintainer's Mac or in CI.
