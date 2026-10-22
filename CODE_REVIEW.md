# Code Review and Fix Plan

**Reviewed revision:** `3851dca` (`develop`, 2026-10-22, `toolVersion` 3.5.3, latest tag `v3.5.2`)
**Scope:** `Sources/AranetKit` (4 files), `Sources/AranetCli` (3 files), `Package.swift`, the three workflows, release scripts, and the agent instruction files
**Method:** line-by-line static review against the `swift-coding-conventions`, `swift-concurrency-pro`, and `swift-testing-pro` skills, with the downstream consumer (senor-particle, reviewed the same day) used to confirm which library behaviors matter in practice
**Not done:** no build, lint, or test run. The review environment has no Swift toolchain. Every phase ends with the macOS commands that verify it.

Line numbers refer to the reviewed revision. Finding IDs are stable and are referenced from the phases in Part 2. Companion review: `CODE_REVIEW.md` in senor-particle; its findings C3, K5, and A9 are consequences of library findings K3, K1, and A6 here.

---

## Executive summary

AranetKit is compact (about 1,100 library lines and 800 CLI lines), has a clean value-type public surface, documents its wire formats carefully, and runs strict `swift-format` linting in CI. The CLI's `--json` mode and the per-peripheral `ReadOperation` isolation are well thought out.

The problems are concentrated in `AranetClient.swift` and fall into four groups:

1. **Isolation is asserted, not checked (K1).** `Package.swift` has no `swiftSettings`, so the module is in Swift 6 language mode with no default isolation. `AranetClient` is a nonisolated class marked `@unchecked Sendable`, with some methods `@MainActor` and some not. `waitForBluetoothReady()` is a nonisolated async function and therefore runs off the main actor while it reads `centralManager.state` and writes `bluetoothReadyContinuation`, which the main-queue delegate also writes. `AGENTS.md` already documents the class as `@MainActor`; the code does not match.
2. **Continuations can be orphaned (K2, K3).** Three single-slot continuation stores (`bluetoothReadyContinuation`, `scanContinuation`, `activeOperations[device.id]`) are overwritten by concurrent calls, leaving the earlier caller suspended forever. The `monitor(from:)` producer task is never cancelled when the consumer stops iterating, so the library keeps connecting to the device on every interval, retaining the client, until the process exits.
3. **No cancellation path (K4).** `scan`, `readCurrentReadings`, and the monitoring `wait(for:)` ignore task cancellation; a cancelled caller waits for the full timeout or the next timer.
4. **No tests, and parsing is locked inside the client (T1, A1).** `AGENTS.md` names Swift Testing and asks for parser and unit tests, but there is no test target, CI runs no tests, and `parseReading` is a private instance method that reads unbounded unaligned loads through nested closures.

Severity counts: **High 6**, **Medium 17**, **Low 24**, Informational 5.

---

# Part 1: Findings

Severity key: **High** = hang, race, or resource leak reachable by a normal consumer; **Medium** = latent defect, wrong error, testability blocker, or structural debt; **Low** = convention, duplication, naming; **Info** = note, no action required.

## K. Concurrency (swift-concurrency-pro)

### K1. `AranetClient` isolation is unchecked and partially off-main — High

`AranetClient.swift:212` declares `public class AranetClient: NSObject, @unchecked Sendable`. `Package.swift` sets no `swiftLanguageMode`, `defaultIsolation`, or upcoming features, so with tools version 6.2 the module compiles in Swift 6 mode with nonisolated defaults and *without* `NonisolatedNonsendingByDefault`. Consequences:

- `waitForBluetoothReady()` (`:237-275`) is `private func … async throws` with no isolation, so it executes on the generic executor. It reads `centralManager.state` (`:242, 249`) and assigns `self.bluetoothReadyContinuation` (`:261`) from a background thread, while `centralManagerDidUpdateState` (`:585-607`) reads and clears the same property on the main queue. The `@unchecked Sendable` hides this from the compiler.
- `public var verbose` (`:228`) is a plain stored property on a `Sendable` class with no synchronization.
- `failOperation`, `failAllOperations`, `completeReading`, `disconnect`, `parseReading`, and the two delegate extensions are nonisolated and happen to run on the main thread only because `CBCentralManager` was created with `queue: .main` (`:232`). Nothing enforces this.
- `AGENTS.md` ("Sendable Conformance for CoreBluetooth") shows `@MainActor public class AranetClient: NSObject, @unchecked Sendable`. The `@MainActor` is missing from the code, and with it present the `@unchecked Sendable` is redundant.

Fix: make the whole class main-actor isolated and drop the unchecked conformance. `CoreBluetooth` is already imported with `@preconcurrency`, so the delegate methods on a `@MainActor` class satisfy the nonisolated protocol requirements with compiler-inserted runtime isolation checks (SE-0423), which pass because the delegate queue is `.main`.

```swift
// Before
public class AranetClient: NSObject, @unchecked Sendable {
    private func waitForBluetoothReady() async throws { … }
    @MainActor public func scan(timeout: TimeInterval = 15.0) async throws -> [AranetDevice] { … }

// After
@MainActor
public final class AranetClient: NSObject {
    private func waitForBluetoothReady() async throws { … }
    public func scan(timeout: TimeInterval = 15.0) async throws -> [AranetDevice] { … }
```

The per-method `@MainActor` annotations (`:282, 328, 404, 455, 518`) and `Task { @MainActor in }` (`:263, 303, 369, 407`) become redundant and go. This is a public API isolation change: consumers that call the client from a nonisolated context must now `await` it (senor-particle already runs on the main actor). See D5 for versioning.

### K2. `monitor(from:)` producer is never cancelled when the consumer stops — High

`AranetClient.swift:404-453` builds the stream with the closure-based `AsyncStream` initializer and starts an unstructured `Task` inside it. There is no `continuation.onTermination` handler and the task handle is discarded. When the consumer's task is cancelled or it breaks out of `for await`, the stream iterator ends but the producer keeps running: `monitoringLoop` (`:455-516`) only checks `Task.isCancelled` on *its own* task, which nobody cancels. It therefore keeps calling `readCurrentReadings` every interval, connecting to the device over Bluetooth, yielding into a stream nobody reads, and posting `aranetReadingDidUpdate` notifications. The `guard let self` at `:408` holds a strong reference for the life of the loop, so the client cannot deallocate either.

senor-particle's `stopMonitoring()` cancels its consumer tasks and expects the library to stop; today it does not.

```swift
// After
public func monitor(from device: AranetDevice) -> AsyncStream<Result<AranetReading, any Error>> {
    let (stream, continuation) = AsyncStream.makeStream(of: Result<AranetReading, any Error>.self)
    let task = Task { [weak self] in
        guard let self else {
            continuation.finish()
            return
        }
        await self.runMonitor(for: device, continuation: continuation)
    }
    continuation.onTermination = { _ in task.cancel() }
    return stream
}
```

### K3. Single-slot continuations are overwritten by concurrent calls — High

Three places store exactly one continuation and assign unconditionally:

| Store | Written at | Overwritten when | Effect on the earlier caller |
| --- | --- | --- | --- |
| `bluetoothReadyContinuation` | `:261` | two calls wait for power-on at once; `monitor` for N devices calls `readCurrentReadings` concurrently, each of which calls `waitForBluetoothReady()` (`:330`) | suspended forever, or resumed never; `CheckedContinuation` logs a leak |
| `scanContinuation` | `:296` | `scan()` called while a scan is running (senor-particle's Rescan from menu and Settings) | the first `scan()` never returns; its timeout task resumes the *second* continuation |
| `activeOperations[device.id]` | `:337` | `readCurrentReadings` for a device that already has an operation in flight | the first operation's `continuation` is orphaned; its timeout task later fails whatever operation now holds the key |

Fix: for `bluetoothReadyContinuation` and `scanContinuation`, keep an array of waiters (or a shared in-flight `Task` that all callers await). For `activeOperations`, throw a new `AranetError.operationInProgress` or await the existing operation's task. All three need a test (T2).

### K4. No cancellation support in `scan`, `readCurrentReadings`, or `wait(for:)` — Medium

- `scan()` (`:292-311`): cancelling the awaiting task does nothing; the BLE scan runs for the full timeout. Wrap in `withTaskCancellationHandler` that calls `stopScan()` and resumes with the devices found so far (or `CancellationError`).
- `readCurrentReadings()` (`:347-393`): cancellation leaves the connection attempt running; the continuation is resumed only by the delegate or the 30-second timeout. The cancellation handler should `failOperation(op, with: CancellationError(), disconnect: true)`.
- `wait(for:)` (`:518-527`): a `Timer` plus `withCheckedContinuation` cannot observe cancellation; the loop notices it only after the timer fires (up to interval + 3 s). `try await Task.sleep(for: .seconds(delay))` is cancellable and does not depend on `RunLoop.main` being serviced. The README's statement that readings keep arriving during AppKit menu tracking stays true, because `Task.sleep` does not go through run-loop modes at all. Requires the macOS 13 floor (D4).

### K5. Timeout tasks check the key, not the operation — Medium

`AranetClient.swift:369-392`. The watchdog task looks up `self.activeOperations[device.id]` after 5 s and 30 s. If the first read completes and a second read for the same device starts within 30 s, the first watchdog fails the *second* operation with `.timeout`. Compare identity (`op === operation`) and cancel the watchdog when the operation completes. The 5 s and 30 s constants are also hard-coded; expose them as `init` parameters or a `Configuration` struct so tests can shorten them.

### K6. `[weak self]` guards that silently drop continuations — Low

`AranetClient.swift:264, 294, 304, 348, 370`. Inside `withCheckedThrowingContinuation` closures (`:294, :348`) a `nil` self returns without resuming, which would hang the caller. `self` cannot be nil there because the method is executing on it; the weak capture is dead weight that makes the code look unsafe. In the watchdog tasks (`:264, :304, :370`) a `nil` self is possible and harmless. Remove the weak captures from the continuation closures; keep them on the detached watchdogs with a comment.

### K7. Legacy sleep API — Low

`AranetClient.swift:265, 305, 373, 385` use `Task.sleep(nanoseconds:)` with manual multiplication. `Task.sleep(for: .seconds(…))` is clearer and typed, but requires macOS 13 (D4). Keep as-is until the platform floor moves.

### K8. `print` as the library's diagnostic channel — Medium

62 `print` calls in `AranetClient.swift` guarded by `verbose`. A library writing to standard output is a problem for every consumer: the CLI has to suppress it in `--json` mode (`GlobalOptions.clientVerbose`), and a menu bar app has no console. Replace with `os.Logger(subsystem: "com.panjas.aranet-kit", category: "client")` at `.debug` level, which is free when disabled and filterable in Console. `verbose` can remain as a convenience that raises the level, or be removed in the major release.

### K9. Notification delivery isolation is undocumented — Low

`AranetNotifications.postReadingDidUpdate` is called from main-actor contexts (`:420, :480`), so selector-based observers in consumers run on the main thread. That is a contract consumers rely on (senor-particle K5). Document it on `Notification.Name.aranetReadingDidUpdate` and keep the posting call inside main-actor code after K1.

### K10. `ProgressSpinner` timer allocates a `Task` per frame — Low

`ProgressSpinner.swift:22-29`. `Timer.scheduledTimer` already schedules on the current run loop; the following `RunLoop.current.add(timer, forMode: .common)` adds it a second time. The block then spawns `Task { @MainActor in }` every 80 ms to hop to an actor it is already on. Create the timer with `Timer(timeInterval:repeats:block:)`, add once in `.common`, and call `MainActor.assumeIsolated { self?.render() }`.

## C. Correctness and behavior

### C1. Negative next-read delay causes an immediate re-read loop — Medium

`AranetClient.swift:428-429` and `:490-491`. `timeUntilNextUpdate = interval - ago` goes negative when the device reports `ago > interval` (clock drift, a reading taken right at the boundary, or a stale device). The delay becomes negative, the timer fires immediately, and the loop reads again at once, repeating until the device's `ago` drops below `interval`. Clamp to a minimum (`max(delay, 1)`), and extract the arithmetic into a pure `MonitorSchedule` value so it can be tested (T2).

### C2. A disconnect during a read is only logged — Medium

`centralManager(_:didDisconnectPeripheral:error:)` (`:640-648`) prints and returns. If the peripheral drops before the reading characteristic arrives, the operation's continuation stays pending until the 30-second watchdog reports `.timeout`, which is the wrong error and a long wait. Fail the active operation for that peripheral immediately with `error ?? AranetError.connectionFailed`.

### C3. Pairing detection depends on the "no data" path only — Medium (confirm on hardware)

`peripheral(_:didUpdateValueFor:error:)` (`:789-826`). An `insufficientEncryption` ATT error (`:792-800`) removes the pending read but does not increment `encryptionErrors`; only a `nil` value with no error (`:811-826`) does. The 5-second watchdog (`:374-382`) reports `.pairingRequired` only when `encryptionErrors > 0`. On a device whose only reading characteristics require pairing (Aranet2 on F0CD1504 per the protocol notes), an ATT error on each would leave the counter at zero and the user gets `.timeout` after 30 s instead of the pairing guidance. Count the ATT encryption error as well, and replace the string/int comparison with `CBATTError.Code.insufficientEncryption`.

### C4. No reading characteristic with name/version reads pending never fails cleanly — Low

`:768-779`. When all services are discovered, the code fails with `.readFailed` only if `pendingReads` is empty. If the GAP name or DIS revision reads are still pending and no reading characteristic was found, nothing fails; `didUpdateValueFor` completes only when `readingData != nil`, so the operation waits for the 30-second watchdog and reports `.timeout`. Track "reading characteristic selected" separately and fail with `.readFailed` as soon as the discovery pass finds none.

### C5. `AranetError` does not conform to `LocalizedError` or `CustomStringConvertible` — Medium

`AranetClient.swift:101-166` defines `description` as a plain property. `error.localizedDescription`, which is what senor-particle logs, yields "The operation couldn't be completed. (AranetKit.AranetError error 2.)". The CLI works around it with `error as? AranetError` in four places (`AranetCli.swift:209, 255, 407, JsonOutput.swift:140`). Add `LocalizedError` with `errorDescription` and declare `CustomStringConvertible`; the CLI casts then disappear.

### C6. Known-peripheral lookup only works after a scan in the same client — Medium

`readCurrentReadings` (`:332-334`) throws `.deviceNotFound` unless `knownPeripherals` holds the id, and that map is only filled by `scan()`. CoreBluetooth can resolve a known identifier without scanning via `centralManager.retrievePeripherals(withIdentifiers:)`. Falling back to it lets consumers persist device ids and reconnect at launch without a 15-second scan, which is exactly what a menu bar app wants.

### C7. Error-path gaps in characteristic discovery — Low

`:697-703`. On a `didDiscoverCharacteristicsFor` error the method returns after incrementing `servicesDiscovered`, so the "all services discovered" check (`:735`) is skipped for that callback. If the failing service was the last one, the completion logic never runs and the read waits for the watchdog. Run the completion check on the error path too.

### C8. CLI `monitor` has no interrupt handling and fails fast for all devices — Medium

`AranetCli.swift:545-583`. `try await group.next()` returns when the first child finishes; children finish only on stream failure, so one device failing ends monitoring for all devices with exit code 1. Ctrl+C terminates the process directly: the `catch is CancellationError` branch (`:578`) is unreachable because nothing cancels the task, and the "Monitoring stopped." text never prints. Install a `DispatchSource.makeSignalSource(signal: SIGINT)` handler that cancels the group (and restores the cursor if a spinner is active), and decide whether one device's failure should stop the others (recommended: report and keep monitoring the rest).

### C9. Spinner writes escape sequences to non-terminal output — Low

`GlobalOptions.showSpinner` (`AranetCli.swift:191-193`) is true whenever `--json` and `--verbose` are absent, regardless of whether stdout is a TTY. `aranet-cli read X > out.txt` writes cursor-hide and carriage-return sequences into the file. Gate on `isatty(STDOUT_FILENO) == 1`.

### C10. JSON encoding failures are silent — Low

`JsonOutput.swift:104-110, 118-124, 130-136`. `try?` drops encoding errors and `emit` returns without output, so a script receives nothing and exit code 0. Encoding these DTOs cannot realistically fail, but the failure mode is the worst possible one for "agent mode". Write the error to stderr and exit non-zero.

### C11. Device matching stops at the first name match — Low

`AranetCli.swift:141-162`. `first(where:)` means a query such as `Aranet4` matches one device even when three are in range, silently ignoring the others. Either match all devices whose name contains the query, or document that a query selects one device.

### C12. `--json` detection scans raw arguments — Low

`AranetCli.swift:332-334`. `CommandLine.arguments.contains("--json")` is true if any argument equals `--json`, including a device query. It exists because errors can be raised before parsing; acceptable, but note it in the doc comment and prefer `jsonFlag` once parsing succeeded.

### C13. Read and monitor use a hard-coded 15-second scan — Low

`scanAndMatchDevices` (`AranetCli.swift:249`) ignores the `--timeout` that `scan` offers. Add `--timeout` to `GlobalOptions` (or to `read`/`monitor`) so all three subcommands agree.

## A. Architecture and structure

### A1. Payload parsing is private, stateful, and unbounded — High (testability)

`parseReading` (`AranetClient.swift:941-1130`) is a private instance method (it needs `self.verbose` for hex dumps) whose nested `readUInt16LE/32/64` closures call `loadUnaligned(fromByteOffset:)` with no bounds check; safety depends on the `data.count` guards placed before each branch (`:975, 986, 989, 1046, 1083, 1111`). The 3.5.3 fix for 11-byte Aranet4 payloads shows how easy it is to get those guards wrong. `AGENTS.md` asks for parser tests, which is impossible while the parser is private to a Bluetooth-bound class.

Fix: extract a pure, internal parser with a bounds-checked reader:

```swift
// AranetPayloadParser.swift
struct AranetPayloadParser {
    static func reading(from data: Data, characteristic: CBUUID?, name: String, version: String) throws -> AranetReading
}

// ByteReader.swift
struct ByteReader {
    private let data: Data
    private(set) var offset: Int

    mutating func uint8() throws -> UInt8 { … }       // throws AranetError.invalidData when out of range
    mutating func uint16LE() throws -> UInt16 { … }
    mutating func uint32LE() throws -> UInt32 { … }
    mutating func uint64LE() throws -> UInt64 { … }
    mutating func skip(_ count: Int) throws { … }
}
```

Hex-dump diagnostics move to the logger (K8) and are driven by the parser's result, not interleaved with parsing. The wire device-type bytes become a `private enum WireDeviceType: UInt8 { case aranet2 = 2, radonPlus = 3, radiation = 4 }` so the `deviceTypeByte == 4` comparisons (`:982, 1045, 1073`) and the `28`/`48`/`10`/`9`/`13` length constants get names tied to the protocol table in `AGENTS.md`.

### A2. Monitoring loop is not separable from the client — Medium (testability)

`monitor(from:)` and `monitoringLoop` (`:404-516`) mix scheduling arithmetic, Bluetooth reads, stream plumbing, and notification posting. Extract `MonitorSchedule` (pure: `nextDelay(interval:ago:)` with the clamp from C1) and a `ReadingMonitor` that takes `read: (AranetDevice) async throws -> AranetReading` and `sleep: (TimeInterval) async throws -> Void` closures. `AranetClient.monitor` composes them with the real read and `Task.sleep`; tests inject fakes and a `confirmation()` for the notification.

### A3. One type per file — Low

| File | Top-level types | Action |
| --- | --- | --- |
| `AranetClient.swift` | `AranetUUID`, `AranetError`, `ReadOperation`, `AranetClient` | `AranetUUID.swift`, `AranetError.swift`; `ReadOperation` can stay as a private nested type |
| `AranetTypes.swift` | `AranetDeviceType`, `AranetStatusColor`, `AranetStatus`, `AranetDevice`, `AranetReading` | five files |
| `Units.swift` | `UnitRadiationDose`, `UnitRadioactivity` | two files |
| `AranetNotifications.swift` | `AranetNotificationKey`, `AranetNotifications` | keep the public key enum; fold the internal helper into `AranetClient` or its own file |
| `AranetCli.swift` | `GlobalOptions`, `AranetCliMain`, `AranetCli` (+ `Scan`, `Read`, `Monitor`, two extensions, two free functions) | `GlobalOptions.swift`, `AranetCliMain.swift`, `AranetCli.swift`, `ScanCommand.swift`, `ReadCommand.swift`, `MonitorCommand.swift`, `AranetReading+TerminalOutput.swift`, `Array+DeviceMatching.swift`, `DeviceScanner.swift` (for `scanAndMatchDevices`) |
| `JsonOutput.swift` | `JsonDevice`, `JsonMeasurement`, `JsonReading`, `JsonError`, `JsonOutput` | `JsonOutput.swift` plus one file per DTO, or keep the DTOs in `JsonPayloads.swift` if the team prefers one exception (record it in `AGENTS.md`) |

The CLI file also still carries the `aranetctl.swift` header (`AranetCli.swift:2-3`).

### A4. Tuples where a named type is clearer — Low

`Array.match(queries:) -> (matched:, notFound:)` (`AranetCli.swift:143`), `scanAndMatchDevices -> (client:, matched:, notFound:)` (`:230`), `[(AranetDevice, Result<AranetReading, Error>)]` repeated three times (`:448-450, 464`), `failures: [(device:, error:)]` (`:477`), the `(range: String, description: String)` field tables (`AranetClient.swift:884, 914, 925`) that are parsed from strings at runtime. Use small structs and `ClosedRange<Int>` for the hex-dump fields.

### A5. `AranetUUID` is a struct used only for statics — Low

`AranetClient.swift:24`. A caseless `enum` prevents meaningless instantiation. Same for `AranetNotifications`.

### A6. Unit coverage gaps that push conversions into consumers — Low

`Units.swift` offers sieverts in four magnitudes and Bq/m³ plus pCi/L. senor-particle re-implements millirem by hand (its A9). Add `UnitRadiationDose.millirems` (1 mrem = 10 µSv = 10,000 nSv) and consider `UnitRadiationDose` per-hour rate semantics in docs (the type is used for both dose and dose rate; the symbol does not carry `/h`).

### A7. Public types lack `Equatable` — Low

`AranetReading` (`AranetTypes.swift:125`) is `Sendable` only. Tests (T2) and consumers that diff readings need `Equatable`; `Measurement` already is. `AranetDevice` is `Hashable` already.

### A8. Library error text addresses CLI users — Low

`AranetError.pairingRequired.description` (`AranetClient.swift:150-163`) says "When you run this command…". Keep library messages generic and let the CLI append command-specific guidance.

### A9. `ProgressSpinner` is `public class` in an executable target — Low

`ProgressSpinner.swift:5`. `public` has no meaning in an executable target; make it `final class` with internal access. ANSI sequences (`:19, 37, 41, 49, 57, 63`) deserve named constants.

### A10. `.gitignore` lists `Package.resolved`, which is tracked — Low

`.gitignore:9` ignores `Package.resolved` while the file is committed and `build.yml` relies on it for reproducible builds. Since the repository ships an executable, keeping it tracked is right; remove the ignore entry so `git status` and the file agree.

### A11. Bluetooth permission prompt at `init` — Info

`AranetClient.init` (`:230-233`) creates `CBCentralManager` immediately, which triggers the TCC prompt at construction. Reasonable for the CLI; document it for library consumers (a menu bar app may want to construct lazily).

### A12. `baseUnit()` forced casts — Info

`Units.swift:63-65, 117-119` use `as! Self` with `swift-format-ignore: NeverForceUnwrap`. This is the standard pattern for `Dimension` subclasses; keep it.

## S. Conventions (swift-coding-conventions)

### S1. Instance members accessed without `self.` — Low (many sites)

`AranetReading` formatting extension (`AranetCli.swift:25-135`: `co2`, `temperature`, `humidity`, `pressure`, `status`, `ago`, `interval`, `radonConcentration`, `radiationRate`, `radiationTotal`, `radiationDuration`, `battery`, `name`, `version`, `deviceType`), `GlobalOptions` (`:182-197`), `AranetCli.run` (`:352`), `Scan.run` (`:376-411`: `options`, `timeout`), `Read.run` (`:432-507`), `Monitor.run` (`:528`), `JsonReading.init` (`JsonOutput.swift:57-80`, mixed: `self.timestamp` qualified, everything else not), `ProgressSpinner` (`:17-65`), and throughout `AranetClient` (`centralManager`, `verbose`, `discoveredPeripherals`, `knownPeripherals`, `activeOperations`, `scanContinuation`, `bluetoothReadyContinuation`, `failOperation`, `completeReading`, `disconnect`, `parseReading`, `printHexDump`). A mechanical pass; swift-format does not enforce it, so a review checklist item is needed.

### S2. Type-level members accessed without `Self.` — Low

`AranetUUID.readingCharacteristicPriority` (`AranetClient.swift:84-87, 91`), `AranetCli.jsonRequested` from inside `AranetCli` (`:305, 312`, and `AranetCli.jsonRequested` at `:182` from another type is correct), `AranetCli.exit`/`exitCode`/`message` inside `AranetCliMain` (correct: different type).

### S3. Implicit returns — Low

`AranetCli.swift:45, 182, 187, 192, 197, 333`. `.swift-format` has `OmitExplicitReturns: false`; these will be flagged by lint in CI once the rule is exercised (D1 verifies whether it is).

### S4. Boolean expressions without explicit comparison — Low

`AranetCli.swift:264` (`if matched.isEmpty`), `:397` (`if devices.isEmpty`), `:102` (`version.hasPrefix("v") ? …`), `JsonOutput.swift:59` (`reading.version.isEmpty ? nil : …`), `ProgressSpinner.swift:51` (`if !symbol.isEmpty`), `AranetClient.swift:768, 774` (`pendingReads.isEmpty` inside compound conditions), `:375` (`op.continuation != nil && op.encryptionErrors > 0 && op.readingData == nil`, three conditions in one `if let … ,` clause), `:249, 602` (`!=` chains that the convention asks to nest).

### S5. Multi-condition guards — Low

`AranetClient.swift:374-376, 422, 662, 697`; `AranetCli.swift:54, 69, 107`. Split where it does not hurt readability.

### S6. Magic numbers — Low

Wire bytes and lengths in `parseReading` (A1 covers them); `nsError.code == 15` (`:792`); timeouts `5_000_000_000`, `25_000_000_000` (`:265, 373, 385`); `+ 3` / `+ 3.0` read margin (`:429, 491, 499`); `60`, `3600`, `86400` in `radiationLines` (`AranetCli.swift:71-73`); spinner `0.08` (`ProgressSpinner.swift:10`, already a constant).

### S7. Line over the configured 147 columns — Low

`AranetClient.swift:795` (152). Wrap it.

### S8. Already compliant (no action)

`else`/`catch` placement, same-line braces, one `case` per line in `switch`, explicit `== true`/`== false` in most of the library, no `try!`, no force unwraps outside the documented `baseUnit()` idiom, ordered imports, DocC comments on every public declaration in `AranetKit`, `swift-format-ignore` used sparingly and with a named rule. The explicit `-> Void` convention is not applied anywhere in this package (every `Void` function omits it); decide whether the skill rule applies here and record it in `AGENTS.md` (D3), since `.swift-format` has `NoVoidReturnOnFunctionSignature: false` and would accept either.

### S9. Doc comments on non-obvious internals — Low

`waitForBluetoothReady` (why `.unknown`/`.resetting` wait but `.poweredOff` throws), the 5 s/30 s watchdog, `ReadOperation.encryptionErrors` semantics, `wait(for:)` (why `.common`), `AranetCliMain.exit(withError:)` (why `ExitCode.success` is special-cased). `AGENTS.md` asks for "why, not what" comments and these are the places a reader asks why.

## T. Testing (swift-testing-pro)

### T1. No test target, no tests, no test step in CI — High

`Package.swift` declares two targets and no `testTarget`; `build.yml` runs `swift build` for debug and release and the architecture check; `release.yml` validates metadata and packages; `lint.yml` lints. `AGENTS.md` names Swift Testing and lists parser and unit-conversion tests as the intended first suites. None exist.

Target state: `Tests/AranetKitTests` and `Tests/AranetCliTests` (the CLI target must expose its formatting and matching helpers to `@testable import`; executable targets can be imported with `@testable` since Swift 5.5), `swift test` in `build.yml` and in the pull-request leg of `release.yml`, and `AGENTS.md` updated to say tests exist and are required.

### T2. Test inventory

Written against the shapes introduced by A1, A2, K3, and C5. Suites are `struct`s, no `@Suite` unless a trait is needed, `#expect(x == false)` never `!x`, `#require` for unwraps, parameterized where cases repeat, `confirmation()` for notifications, no sleeps, injected clocks.

| Suite | What it proves | Depends on |
| --- | --- | --- |
| `AranetPayloadParserTests` | Aranet4: 13-byte full payload, 9-byte basic payload (no interval/ago), 11- and 12-byte payloads (no interval/ago, no crash), 8 bytes → `.invalidData`; status bytes 0–3 map, 4 → `nil`. Radiation: 28-byte F0CD1504 (rate ÷ 10), 48-byte F0CD3003 (rate as-is), 30 bytes → `.invalidData`, status 0x05/0x0A/0x0B/other. Aranet2: 10 bytes parse, 9 → `.invalidData`. Wire type 3 and unknown → `.invalidData`. Little-endian correctness with asymmetric byte values. Hex fixtures taken from the tables in `AGENTS.md` | A1 |
| `ByteReaderTests` | every read at the exact end succeeds, one past the end throws, offsets advance by width | A1 |
| `UnitsTests` | nSv↔µSv↔mSv↔Sv round trips, Bq/m³↔pCi/L with coefficient 37, `baseUnit()` identity, `Measurement` equality across units, new `millirems` (A6) | none |
| `MonitorScheduleTests` | `interval − ago + 3` normal case, `ago > interval` clamps to the minimum (C1), missing `ago` uses `interval + 3`, interval change adopted on next cycle | A2 |
| `ReadingMonitorTests` | initial read failure finishes the stream with `.failure`; successful reads yield in order; cancelling the consumer ends the producer within one `sleep` call (K2, verified via the fake `sleep` being cancelled); one `aranetReadingDidUpdate` per reading (`confirmation(expectedCount:)`) | A2, K2 |
| `ContinuationRegistryTests` | two concurrent waiters for Bluetooth readiness both resume; second concurrent `scan` either joins the first or throws, never hangs; second `readCurrentReadings` for the same device throws `.operationInProgress` (K3) — testable once the registry is a small value type separate from CoreBluetooth | K3 |
| `AranetErrorTests` | every case has a non-empty `errorDescription`; `localizedDescription` equals it (C5) | C5 |
| `DeviceMatchingTests` | exact UUID (case-insensitive), name substring, duplicate queries collapse, unmatched queries reported, multi-match policy (C11) | none |
| `JsonReadingTests` | keys sorted and stable, absent measurements omitted, ISO 8601 timestamp, units per field, single-line output when `pretty == false` | none |
| `TerminalOutputTests` | per-device-type line sets, version prefix handling, duration formatting (`1d 2h 3m`) | none |

Tags: `.parsing`, `.units`, `.monitoring`, `.cli`. Fixtures: `Tests/AranetKitTests/Fixtures/Payloads.swift` with named `Data` constants per characteristic and device.

### T3. Concurrency testing

Per `swift-concurrency-pro/references/testing.md`: `ReadingMonitorTests` drive a fake `read` closure and a fake `sleep` that suspends on a continuation the test controls, then cancel the consuming task and assert the producer observed cancellation. No timing-based waits. Add a CI job that runs `swift test` with `-Xswiftc -sanitize=thread` once the suite exists.

### T4. Hardware tests — Info

CoreBluetooth stays unmocked, as `AGENTS.md` decides. Keep the manual `swift run aranet-cli <command> --verbose` checklist, and add the two scenarios this review could not verify statically: C3 (pairing detection on Aranet2) and C1 (device reporting `ago > interval`).

## D. Tooling and documentation

### D1. CI runs no tests — Medium

Add to `build.yml` after the debug build and to the `validate` job in `release.yml`:

```bash
swift test
```

Also confirm whether `swift-format lint --strict` reports `OmitExplicitReturns` and line-length findings in this configuration; if S3 and S7 are not currently failing CI, the lint gate is weaker than `AGENTS.md` implies.

### D2. `AGENTS.md` architecture snippets do not match the code — Medium

- "Sendable Conformance for CoreBluetooth" shows `@MainActor … @unchecked Sendable`; the code has no `@MainActor` (K1). After K1 the snippet should show `@MainActor public final class AranetClient: NSObject` with the SE-0423 explanation.
- "Controller/Service Pattern" shows `@Command var read: ReadCommand`, which is not swift-argument-parser syntax; the real structure is `CommandConfiguration(subcommands:)`.
- "Testing" says the package has no test target; update when T1 lands.
- "Code Review" bullet: add a pointer to this file.

### D3. Convention decisions to record — Low

`-> Void` on every function (S8), one-type-per-file exception for the JSON DTOs (A3), `self.` qualification (S1) as a review checklist item since the formatter cannot enforce it.

### D4. Platform floor — Medium (decision)

`Package.swift` declares `.macOS(.v12)`. `Task.sleep(for:)`, `ContinuousClock`, and typed `Duration` need macOS 13; `isolated deinit` needs 15.4. CoreBluetooth and Swift 6.2 toolchains are only tested on current macOS in CI (`macos-15`), and the only known consumer targets 15.7. Raising the floor to `.macOS(.v13)` (or `.v14`) unlocks K4 and K7 cleanly; staying on 12 means keeping `Task.sleep(nanoseconds:)` and `Timer`-based waits. Recommended: `.macOS(.v13)` in the same major release as K1.

### D5. Versioning — Medium (decision)

K1 changes the isolation of a public class, K2 changes `monitor(from:)` termination semantics, K3 adds an error case, D4 raises the platform floor. Together they are a MAJOR per the `semantic-versioning` skill: **4.0.0**. A1, A2, C1, C2, C4, C7, and the CLI changes are PATCH or MINOR and could ship first as 3.5.4/3.6.0 if a smaller step is wanted. senor-particle depends on `3.5.2` with up-to-next-major, so it must opt into 4.0.0 explicitly; its own plan (Phase 1, `SensorClient` protocol) is where that happens.

### D6. `CHANGELOG.md` and release scripts — Info

`Scripts/verify-version.sh` ties `toolVersion` to the newest `CHANGELOG.md` section. Every phase below that bumps the version must add a changelog section in the same commit, or the release validation fails.

---

# Part 2: Fix plan

Six phases. Phases 0–1 are internal and safe to ship as a patch. Phases 2–3 change public behavior and ship together as 4.0.0. Phases 4–5 are CLI and hygiene. Size: S = under half a day, M = one to two days, L = several days. Commits need explicit confirmation per the project's commit protocol, and each code-changing commit carries its version bump and changelog section.

## Phase 0: Safety net (size S)

**Milestone M0: `swift test` runs in CI on every push with a real, if small, suite.**

Findings: T1 (target), D1, S7, D4 (decision only).

1. Add `testTarget(name: "AranetKitTests", dependencies: ["AranetKit"])` and `testTarget(name: "AranetCliTests", dependencies: ["AranetCli"])` to `Package.swift`.
2. First suites that need no refactoring: `UnitsTests`, `DeviceMatchingTests`, `JsonReadingTests`, `TerminalOutputTests`, `AranetErrorTests` (description non-empty only; the `LocalizedError` expectation joins in Phase 2).
3. Add `swift test` to `build.yml` (after the debug build) and to the `validate` job in `release.yml`. Verify the lint gate's actual coverage (D1).
4. Wrap `AranetClient.swift:795`.
5. Decide D4; if the floor moves, change `platforms` now so later phases can use the modern APIs.
6. `AGENTS.md`: Testing section (tests exist, Swift Testing, `swift test` required), Code Review bullet → this file. `UPDATES.md` entry. Version: 3.5.4 with a changelog section ("Added: unit test targets").

Acceptance: `swift test` passes locally and in both workflows; lint stays green.

Commits: `test(kit): add unit test targets`, `ci: run swift test in build and release validation`, `docs(agents): record testing and review process`.

## Phase 1: Parser extraction (size M)

**Milestone M1: every documented payload layout has a passing test, and no byte is read without a bounds check.**

Findings: A1, S6 (wire constants), A7, A3 (`AranetTypes.swift` split), S9 (parser docs).

1. Add `ByteReader` and `AranetPayloadParser` (internal). Port `parseReading` branch by branch; `AranetClient.completeReading` calls the parser and logs the hex dump from the result.
2. `WireDeviceType` enum and named payload lengths referencing the `AGENTS.md` tables.
3. `AranetReading: Equatable`.
4. Split `AranetTypes.swift` into one file per type.
5. Tests: `AranetPayloadParserTests` and `ByteReaderTests` from T2, with fixtures derived from the byte tables. Include the 3.5.3 regression cases (8, 11, 12 bytes).
6. Version: 3.5.5 (PATCH, internal refactor plus tests) or fold into 3.6.0 with Phase 4's CLI additions. `CHANGELOG.md` section. `UPDATES.md` entry.

Acceptance: parser tests pass; `swift run aranet-cli read <device> --verbose` on an Aranet4 and an Aranet Radiation produce output identical to 3.5.3 (compare the hex dump and values).

Commits: `refactor(kit): extract bounds checked payload parser`, `test(kit): cover every documented payload layout`, `refactor(kit): split AranetTypes into one file per type`.

## Phase 2: Client isolation and continuation safety (size M–L)

**Milestone M2: `AranetClient` is `@MainActor`, no continuation can be orphaned, and consumers get useful `localizedDescription`s. Ships as 4.0.0 together with Phase 3.**

Findings: K1, K3, K5, K6, K8, C2, C3, C4, C5, C7, A8, A5, A3 (`AranetClient.swift` split).

1. `@MainActor public final class AranetClient: NSObject`; remove `@unchecked Sendable`, per-method `@MainActor`, and `Task { @MainActor in }`. Keep `@preconcurrency import CoreBluetooth` so the delegate conformances compile with runtime isolation checks. Build with `-strict-concurrency=complete` and fix every diagnostic rather than silencing it.
2. Replace the three single-slot continuations (K3): `bluetoothReadyWaiters: [CheckedContinuation<Void, any Error>]`, a shared `scanTask: Task<[CBPeripheral], any Error>?` that concurrent `scan()` calls await, and `AranetError.operationInProgress` for duplicate reads. Resume waiters in `centralManagerDidUpdateState` and on timeout.
3. Watchdog identity check and cancellation on completion (K5); make the 5 s/30 s limits `init` parameters with defaults.
4. Fail active operations on disconnect (C2), count ATT encryption errors (C3), fail early when no reading characteristic exists (C4), run the completion check on the characteristic-discovery error path (C7).
5. `AranetError: LocalizedError, CustomStringConvertible` (C5); generic pairing text (A8); CLI drops its `as? AranetError` casts.
6. `os.Logger` replaces `print` (K8); `verbose` maps to log level.
7. Split `AranetUUID` (as an enum, A5) and `AranetError` into their own files.
8. Tests: `ContinuationRegistryTests` (the registry is a small main-actor value type), `AranetErrorTests` extended with `localizedDescription`.
9. `AGENTS.md`: replace the Sendable snippet (D2), document the main-actor contract for delegate callbacks and notifications (K9). `UPDATES.md` entry. `CHANGELOG.md` "Changed/Breaking" section for 4.0.0 (held until Phase 3 lands if both ship together).

Acceptance: `swift build -Xswiftc -strict-concurrency=complete` has zero warnings; two concurrent `scan()` calls from a test both return; `read` of two devices concurrently still works on hardware; senor-particle builds against the branch with its `SensorClient` protocol.

Commits: `refactor(kit)!: isolate AranetClient on the main actor`, `fix(kit): keep every waiter and scan continuation`, `fix(kit): fail reads on disconnect and missing characteristics`, `feat(kit): conform AranetError to LocalizedError`, `refactor(kit): log diagnostics with os.Logger`.

## Phase 3: Monitoring lifecycle (size M)

**Milestone M3: stopping a consumer stops the Bluetooth polling; cancellation is honored within one sleep; scheduling arithmetic is tested.**

Findings: K2, K4, K7, C1, C6, A2, K9 (docs).

1. `AsyncStream.makeStream(of:)` with `onTermination` cancelling the producer task (K2).
2. Extract `MonitorSchedule` and `ReadingMonitor` (A2); clamp negative delays (C1); `Task.sleep(for:)` replaces the `Timer` wait (K4, K7; requires D4).
3. `withTaskCancellationHandler` in `scan()` and `readCurrentReadings()` (K4).
4. `retrievePeripherals(withIdentifiers:)` fallback in `readCurrentReadings` (C6), documented as "scan is optional when the identifier is known".
5. Tests: `MonitorScheduleTests`, `ReadingMonitorTests` including the cancellation and notification-count cases; TSan job (T3).
6. README: update the monitoring section (termination semantics, cancellation, no run-loop dependency). `UPDATES.md` entry. `CHANGELOG.md` 4.0.0 section completed; `toolVersion` → 4.0.0.

Acceptance: a test proves the producer stops after consumer cancellation; on hardware, `aranet-cli monitor` followed by Ctrl+C (after Phase 4) leaves no connection open (verify with `--verbose` that no further reads occur); senor-particle `stopMonitoring()` stops Bluetooth activity (observe in Console with the new logger).

Commits: `fix(kit)!: stop monitoring when the stream is cancelled`, `refactor(kit): extract monitor schedule and reading monitor`, `feat(kit): honor task cancellation in scan and read`, `feat(kit): reconnect to known peripherals without scanning`, `chore(release): bump version to 4.0.0`.

## Phase 4: CLI hardening (size M)

**Milestone M4: the CLI is split per command, handles Ctrl+C, never writes escape codes to a pipe, and surfaces every failure.**

Findings: C8, C9, C10, C11, C12, C13, A3 (CLI files), A4, A9, K10, S1–S4 (CLI).

1. Split `AranetCli.swift` and `JsonOutput.swift` per the A3 table; fix the stale file header.
2. SIGINT handling and per-device failure policy for `monitor` (C8).
3. TTY gate for the spinner (C9); spinner timer without per-frame tasks (K10); `final` internal class with named ANSI constants (A9).
4. JSON encoding failure → stderr and non-zero exit (C10); matching policy (C11); `--json` detection note (C12); `--timeout` on read/monitor (C13).
5. Replace tuples with `DeviceMatch`, `ScanResult`, `ReadOutcome` structs (A4).
6. `self.` qualification, explicit returns, `== true`/`== false` across the CLI (S1–S4).
7. Tests: extend `DeviceMatchingTests`, `JsonReadingTests`, `TerminalOutputTests` for the new behavior.
8. README: `--timeout` on all commands, Ctrl+C behavior, multi-match rule. Version: MINOR (4.1.0) if after Phase 3, else 3.6.0. `CHANGELOG.md`, `UPDATES.md`.

Acceptance: `aranet-cli read X > out.txt` produces clean text; Ctrl+C during `monitor` prints "Monitoring stopped." and exits 0; `swift test` green.

Commits: `refactor(cli): split commands into their own files`, `feat(cli): handle interrupt and keep monitoring other devices`, `fix(cli): only animate the spinner on a terminal`, `feat(cli): add timeout option to read and monitor`, `style(cli): apply coding conventions`.

## Phase 5: Convention sweep and documentation (size S)

**Milestone M5: lint clean, greps clean, `AGENTS.md` matches the code.**

Findings: S1 (library), S2, S5, S6 (remaining), S9, A3 (remaining), A6, A10, D2, D3.

1. `self.`/`Self.` pass over `AranetClient.swift` and the remaining library files; split `Units.swift` and `AranetNotifications.swift`.
2. Add `UnitRadiationDose.millirems` with tests (A6); remove `Package.resolved` from `.gitignore` (A10).
3. Doc comments listed in S9.
4. `AGENTS.md`: fix the Controller/Service snippet, record the `-> Void` decision and the one-type-per-file exception if taken (D3), update the Testing section. `UPDATES.md` entry.

Verification greps (all must return nothing, run from the repository root):

```bash
grep -rnE '^\s*(var|static var) \w+: [A-Za-z?]+ \{$' -A1 Sources | grep -vE 'return|\{$|^--$|get \{|switch|guard|if |let '
grep -rnE '!\w+\.isEmpty|if \w+\.isEmpty \{' Sources
grep -rn 'print(' Sources/AranetKit
grep -rn '@unchecked Sendable' Sources/AranetKit/AranetClient.swift
for f in Sources/*/*.swift; do n=$(grep -cE '^(public |final |private |fileprivate )*(class|struct|enum|actor|protocol) ' "$f"); [ "$n" -gt 1 ] && echo "$f: $n"; done
awk 'length > 147 {print FILENAME":"FNR}' Sources/*/*.swift
```

Commits: `style(kit): apply coding conventions`, `feat(kit): add millirem radiation dose unit`, `docs(agents): align architecture notes with the code`.

## Phase 6: Downstream adoption (size S, in senor-particle)

**Milestone M6: senor-particle runs on AranetKit 4.0.0 and drops its workarounds.**

1. Bump the dependency to `from: "4.0.0"` in senor-particle's project.
2. Remove the manual pCi/L and mrem constants (senor-particle A9) in favor of the library units.
3. Keep the rescan guard (senor-particle C3) as defense in depth, but it is no longer the only thing preventing a hang.
4. Log `error.localizedDescription` as today; it now carries the library's message (C5).

---

# Part 3: Decisions needed from the maintainer

1. **D4 platform floor:** raise to macOS 13 (recommended) or keep 12 and skip the modern sleep APIs?
2. **D5 release shape:** one 4.0.0 with Phases 2 and 3, or 3.5.x patches for Phases 0–1 first (recommended: patches first, then 4.0.0)?
3. **K3 duplicate read policy:** throw `operationInProgress` (recommended, explicit) or await the in-flight read?
4. **C8 monitor failure policy:** stop all devices on one failure (current) or report and continue (recommended)?
5. **C11 matching:** first match (current) or all matches?
6. **S8 `-> Void`:** adopt the skill's explicit `-> Void` here, or record an exception in `AGENTS.md`?
7. **A3 JSON DTOs:** one file per DTO, or a recorded exception keeping them in `JsonPayloads.swift`?

# Part 4: Verification commands (macOS, Swift 6.2 toolchain)

```bash
# Lint (the CI gate)
xcrun swift-format lint --configuration .swift-format --recursive --strict Sources Tests

# Format
xcrun swift-format format --configuration .swift-format --in-place --recursive Sources Tests

# Build with every strict-concurrency diagnostic surfaced
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors

# Unit tests
swift test

# Unit tests under Thread Sanitizer
swift test -Xswiftc -sanitize=thread

# Release build and architecture check
swift build -c release
Scripts/verify-binary-architecture.sh "$(swift build -c release --show-bin-path)/aranet-cli"

# Version and changelog agreement
Scripts/verify-version.sh

# Hardware checks (real devices)
swift run aranet-cli scan --verbose
swift run aranet-cli read <device> --verbose
swift run aranet-cli monitor <device> --verbose   # then Ctrl+C
```
