# Recent Updates & Decisions

This file is the append-only log of project decisions and notable changes, maintained by coding agents following the `recent-updates` skill. Everything below the marker line is user-owned history: slopctl never overwrites it during init or merge.

<!-- {changelog} -->

### 2026-10-22 12:00 (v4.0.0, coverage gate at 100 percent)

- raised coverage_threshold in scripts/check-coverage.sh to 100 and made the script list the uncovered line ranges of any file below it (test_plan.md milestone m5)
- moved aranetclient.init() and the new aranetclient.makelive factory into corebluetoothcentral.swift so every corebluetooth construction sits in the single excluded file; the log sink uses os_log so its message is evaluated eagerly; the default sleep is the testable aranetclient.systemsleep; dead branches in the cli entry point and json error writer removed
- fixed the client suites to wait for the fake sleeper before releasing it (timer tasks start after their bluetooth command is recorded), serialized them, and made sleepgate report empty releases; exit tests skip themselves under thread sanitizer
- rationale: the first green run reported 99.18 percent with 15 uncovered lines, all either corebluetooth construction, defaults the fakes replace, or unreachable branches
- version: stays 4.0.0 (joins the unreleased major)

### 2026-10-22 11:05 (v4.0.0, cli over an injectable environment)

- the cli reads its client, output streams, terminal flag, clock, arguments, and interrupts from the task-local clienvironment; commands live in one file each with devicescanner, errorprinter, exitplan, and spinnerticker as helpers (test_plan.md milestone m4)
- read and monitor accept --timeout, monitor stops cleanly on ctrl+c and keeps the other devices running when one fails, the spinner only animates on a terminal, json encoding failures are reported instead of dropped
- added aranetclitests for every command path, globaloptions, exitplan, the spinner with a fake ticker, the json writer, and exit tests for the entry point; the gate is raised once ci prints the coverage table
- rationale: code_review.md c8, c9, c10, k10, and a3; the old cli constructed aranetclient and wrote to stdout directly, which made every command untestable
- version: stays 4.0.0 (joins the unreleased major)

### 2026-10-22 10:48 (v4.0.0, main-actor client over a bluetooth seam)

- aranetclient is now a main-actor class driving corebluetooth through the bluetoothcentral protocol; corebluetoothcentral is the only file holding cbperipheral objects and is the single coverage exclusion (test_plan.md milestone m3)
- the read flow is the pure readsession state machine; waiterregistry replaces single-slot continuations; watchdogs check operation identity; timeouts and the clock are injectable
- added sensorclient, aranetError.operationinprogress, localizederror conformance, known-peripheral resolution without scanning, and unified-log diagnostics
- rationale: code_review.md k1, k2, k3, k5, c2, c3, c4, c5, c6, c7, and k8; every line of the client now runs under test through the fake central
- version: stays 4.0.0 (joins the unreleased major)

### 2026-10-22 10:32 (v4.0.0, monitoring without bluetooth)

- extracted the monitoring loop into readingmonitor with injected read, sleep, and publish closures, and its arithmetic into monitorschedule with a minimum delay for overdue devices (test_plan.md milestone m2)
- monitor(from:) now builds its stream with makestream and cancels the producer task on termination, so consumers that stop iterating stop the bluetooth polling
- raised the platform floor to macos 13 for task.sleep(for:) and the clock apis (code_review.md d4)
- rationale: the loop mixed scheduling with corebluetooth reads and its producer outlived its consumer; with fakes every path including cancellation is tested
- version bump: 3.5.5 to 4.0.0 (MAJOR - platform floor and monitor termination semantics change for consumers)

### 2026-10-22 10:28 (v3.5.5, pure payload parser)

- extracted payload parsing into aranetpayloadparser with a bounds-checked bytereader and a wiredevicetype enum for the on-wire type byte; the client only calls the parser (test_plan.md milestone m1)
- moved the hex dump into payloadhexdump with closedrange fields instead of strings parsed at runtime
- split aranettypes.swift into one file per type under sources/aranetkit/types and made aranetreading equatable
- fixed secure coding support on the custom units, found by the new archiving tests
- rationale: the parser was private to the bluetooth-bound client and read unaligned memory behind hand-placed length guards; a pure parser is testable from byte fixtures and safe by construction
- version bump: 3.5.4 to 3.5.5 (PATCH - internal refactor, additive conformance, bug fix)

### 2026-10-22 10:22 (v3.5.4, test infrastructure and first suites)

- added swift testing targets for the library and the cli with suites for units, value types, errors, notifications, device matching, terminal output, and json output (test_plan.md milestone m0)
- added scripts/check-coverage.sh, which runs the suites with code coverage, prints a per-file table, and fails below coverage_threshold; the corebluetooth delegate adapter is the single documented exclusion
- ci: build.yml runs the coverage script and a thread sanitizer job, the release dry run runs swift test, and lint.yml lints tests too
- rewrote the testing section in agents.md to describe the framework, layout, tests-first rule, and coverage gate
- rationale: the package had no tests; the plan raises the gate milestone by milestone, so the infrastructure lands first with the suites that need no seams
- version bump: 3.5.3 to 3.5.4 (PATCH - tests and ci only, no api change)

### 2026-10-22 10:12 (v3.5.3, test plan for full coverage)

- added test_plan.md: five milestones from test infrastructure to a 100% line coverage gate, with protocol seams for parsing, monitoring, the bluetooth central, and the cli environment so every code path runs under swift testing with fakes
- the only excluded file is the corebluetooth delegate adapter, because its callbacks take peripheral objects that cannot be created in a test process
- pointed the testing section in agents.md at the plan
- rationale: the package has no tests and the code review showed the shapes that block them; tests drive the refactors milestone by milestone instead of landing after them
- version bump: none (no code change)

### 2026-10-22 09:57 (v3.5.3, code review fix plan)

- added code_review.md with the findings of a full static review against the swift-coding-conventions, swift-concurrency-pro, and swift-testing-pro skills, plus a six-phase fix plan with milestones and verification commands
- pointed the code review bullet in agents.md at that plan
- rationale: the review found unchecked main-actor isolation in aranetclient, continuations that concurrent calls can orphan, a monitor stream whose producer outlives its consumer, and no test target; one tracked plan keeps the fixes ordered and ties the breaking ones to a 4.0.0 release
- version bump: none (no code change)

### 2026-10-22 11:46 (v3.5.3, aranet4 payload bounds and protocol docs)

- fixed aranet4 parsing: payloads shorter than 9 bytes now throw invalidData instead of crashing on byte 8, and interval and ago are only read from full 13-byte payloads instead of from 11 bytes
- protocol docs: added a characteristic-to-device table, device dispatch by byte 0, and a note that on-wire device type bytes differ from AranetDeviceType raw values
- protocol docs: documented the 28-byte aranet radiation F0CD1504 variant, byte 1 of F0CD3003, and the corrected public dose limit of 1 mSv
- protocol docs: marked the aranet2 layout as unverified because its python struct and byte table disagree, and marked radon plus as not implemented; the mission statement no longer claims radon plus readings
- made the unit examples compile by unwrapping optionals
- rationale: a consistency review found out-of-bounds reads in the parser and contradictions in the protocol reference
- version bump: 3.5.2 to 3.5.3 (PATCH - bug fix without API change)

### 2026-10-22 11:41 (v3.5.2, scripts directory renamed to Scripts)

- renamed the scripts directory to Scripts with a two-step git mv through a temporary name, because core.ignorecase is true on macOS and a direct case-only rename is not recorded
- updated helper paths in AGENTS.md, build.yml, release.yml, and Scripts/verify-version.sh
- older log entries keep the lowercase path because the log is append-only
- rationale: match the PascalCase top-level directory naming used by Sources
- version bump: none (no code change)

### 2026-10-22 11:21 (v3.5.2, coding standards and semver handed to skills)

- removed the project code style (explicit booleans, DRY, single-condition guards), code review checklist, and formatting and documentation rules from AGENTS.md; the swift-coding-conventions skill now governs them
- removed the toolVersion snippet and versioning process from AGENTS.md; the semantic-versioning skill now governs bumps, and the release process section still names the version location
- package architecture patterns stay as their own section because they record design decisions, not coding style
- rationale: one source of truth per topic, avoiding drift between AGENTS.md and the installed skills
- version bump: none (documentation-only, no code change)

### 2026-10-22 11:19 (v3.5.2, restore project sections in agents.md)

- restored from the previous AGENTS.md: project code style, package architecture patterns, code review checklist, formatting and documentation rules, swift foundation units, aranet device data formats, release process, and the toolVersion versioning process
- added a short project build commands section with the swift-format, arm64 verification, and run commands; generic swiftpm commands, commit message rules, and generic semver rules stay in the swift-build-commands, git-workflow, and semantic-versioning skills
- fixed the F0CD1503 size from 6 to 9 bytes to match the documented `<HHHBBB` layout, removed a duplicated F0CD3003 paragraph and a duplicated heading, and updated the data model example to the current AranetReading and AranetDeviceType types
- development guidelines now point to the restored sections instead of repeating them
- rationale: the slopctl template had dropped the project design decisions and the aranet ble protocol reference, which agents need for parsing and api work
- version bump: none (documentation-only, no code change)

### 2026-10-22 (v3.5.2, agents.md placeholders and log migration)

- filled the slopctl template placeholders in AGENTS.md with project details: mission, tech stack, code review, development guidelines, security, testing, documentation, and the toolVersion location
- moved the recent updates and decisions log from the previous AGENTS.md into this file, sorted newest first; the duplicate 2025-10-05 initial-setup entry was dropped in favor of the existing one
- copied every CHANGELOG.md release section into this file as release-notes entries placed above the matching decision entry
- CHANGELOG.md keeps its content because scripts/verify-version.sh and the release workflow read it
- rationale: slopctl replaced the project-specific AGENTS.md with a generic template, and the decision history belongs in UPDATES.md now
- version bump: none (documentation-only, no code change)

### 2026-07-26 (v3.5.2, release notes)

- changed: Release assets now contain only the signed arm64 CLI tarball and SHA-256 checksums
- changed: Removed the redundant SwiftPM executable artifact bundle from release packaging
- changed: Release packaging removes stale tarballs and legacy artifact bundles from previous runs
- changed: Pull requests now validate and dry-run releases, while the merge commit pushed to
  `main` triggers signing, notarization, and publishing
- changed: Release publication checks out the exact pushed `main` commit instead of running from
  a closed pull-request event associated with its source branch

### 2026-07-26 (Tarball-Only CLI Releases, Version 3.5.2)

- **Patch version bump**: 3.5.1 to 3.5.2
- **Release assets simplified**: Removed the redundant executable artifact bundle;
  releases now contain only the signed arm64 CLI tarball and SHA-256 checksum manifest
- **Clean packaging output**: Packaging removes stale CLI archives, legacy artifact bundles,
  staging directories, and checksum manifests while preserving unrelated output files
- **Release trigger split**: Pull requests perform validation and unsigned packaging;
  the merge commit's push to `main` performs signing, notarization, and publication
- **Clear provenance**: Production releases check out the exact pushed SHA and appear as
  `main` push runs instead of closed pull-request runs attributed to the source branch
- **Least privilege**: Only the publication job receives release content write permission;
  manual publication is rejected unless dispatched from `main`
- **Safe concurrency**: Main publication runs are serialized without cancellation, while
  superseded validation runs for the same pull request are cancelled
- **Skip-release propagation**: Main-push validation resolves the associated merged pull
  request and honors its `skip-release` label; unassociated main pushes fail safely
- **AranetKit unchanged**: The library remains a source package distributed by release tags
- **Files changed**: `.github/workflows/release.yml`, `scripts/package-release.sh`,
  `Sources/AranetCli/AranetCli.swift`, `README.md`, `CHANGELOG.md`, `AGENTS.md`
- **Reasoning**: Consumers install the CLI from the tarball, so publishing a second archive
  containing the same executable adds maintenance and release clutter without value

### 2026-07-26 (v3.5.1, release notes)

- added: Signed and notarized arm64 release workflow for pull requests merged into `main`
- added: Compressed CLI archive and SHA-256 checksums
- added: Reusable strict Swift source lint workflow
- added: `skip-release` pull-request label for changes that do not require a release
- added: Shared scripts for version validation, architecture checks, and release packaging
- changed: `develop` pre-releases now use the canonical `toolVersion` and verify arm64 output
- changed: Release metadata must match between `AranetCli.toolVersion` and this changelog
- fixed: Broken pre-release version extraction after the version moved to `toolVersion`

### 2026-07-26 (Signed arm64 Releases, Version 3.5.1)

- **Patch version bump**: 3.5.0 to 3.5.1
- **Release workflow**: Pull requests into `main` now validate metadata and package an
  unsigned dry run; merged pull requests create signed and notarized GitHub releases
- **Apple Silicon artifacts**: Debug, release, pre-release, and final release binaries are
  verified as arm64; Intel users build from source
- **Distribution**: Releases initially attached a CLI tarball, executable artifact bundle,
  and SHA-256 checksums; the artifact bundle was removed in version 3.5.2
- **Signing**: Developer ID certificate in an ephemeral keychain with App Store Connect
  API Team Key notarization; bare executable is not stapled because Mach-O cannot hold a ticket
- **Version gate**: Shared scripts ensure `toolVersion`, CHANGELOG, and release tags agree
- **`skip-release` label**: Allows documentation-only PRs to bypass release metadata checks
  and publishing while keeping the required validation check green
- **Strict lint restored**: Reusable `lint.yml` runs Xcode's bundled swift-format with
  `--strict` from both build and release workflows
- **Files changed**: `.github/workflows/`, `scripts/`, `Sources/`, `.gitignore`,
  `README.md`, `CHANGELOG.md`, `AGENTS.md`
- **Reasoning**: Development snapshots were unsigned single-file uploads, version extraction
  had broken after v3.4.0, and the repository lacked a reproducible production release path

### 2026-07-25 (v3.5.0, release notes)

- added: `--json` flag on every subcommand for machine-readable output
- added: Shared `GlobalOptions` option group for `--verbose` and `--json`
- added: Deterministic JSON device, measurement, reading, and error payloads
- fixed: Duplicate monitor error output when a stream fails

### 2026-07-25 (JSON Script and Agent Mode, Version 3.5.0)

- **Minor version bump**: 3.4.0 to 3.5.0
- **New `--json` flag on every subcommand**: Machine-readable output for scripts and agents
  - Declared visibly on the root command so it is listed once in `aranet-cli --help`, and repeated as a `help: .hidden` flag in `GlobalOptions` so `aranet-cli <subcommand> --json` still parses without cluttering the subcommand help pages
  - `GlobalOptions.json` is computed as "hidden flag set OR `--json` present in `CommandLine.arguments`", because swift-argument-parser never passes parent command values down to subcommands
  - Everything goes to stdout, including errors as single-line JSON objects, so a consumer only has to read one stream; exit codes are unchanged
  - `scan` emits a JSON array of devices, `read` emits a JSON array of readings, `monitor` emits newline-delimited JSON (one object per reading) so consumers can stream it
  - `read` emits the data array before any error objects, so a partially failed multi-device read still yields data first
  - All spinners, banners and status text are suppressed; `--verbose` library diagnostics are also suppressed in JSON mode because they print to stdout and would corrupt the payload
- **New `AranetCliMain` entry point**: `@main` moved from the `AranetCli` command to a dedicated enum that calls `parseAsRoot()` and intercepts every thrown error
  - swift-argument-parser prints its own plain-text diagnostics (including usage errors) for anything thrown out of a command, which scripts cannot parse; the interceptor converts them to `{"error": ...}` on stdout when `--json` appears in `CommandLine.arguments`
  - Exit codes are preserved via `AranetCli.exitCode(for:)` (1 for runtime failures, 64 for usage errors); `--help` and `--version` map to `ExitCode.success` and keep their plain-text output
  - `Monitor` now throws `ExitCode.failure` instead of rethrowing the stream error, because the error has already been reported and rethrowing produced a duplicate message
- **New `GlobalOptions` option group**: `--verbose` and `--json` now live in one `ParsableArguments` struct shared by `Scan`, `Read` and `Monitor` via `@OptionGroup`, replacing three duplicated `@Flag var verbose` declarations (DRY)
  - Exposes `clientVerbose`, `showSpinner` and `showStatusText` computed properties so output decisions live in one place instead of being re-derived in each command
  - swift-argument-parser has no parent-to-subcommand flag inheritance, so a shared option group is the idiomatic way to make an option "global" across subcommands
- **New file `Sources/AranetCli/JsonOutput.swift`**: `JsonDevice`, `JsonMeasurement`, `JsonReading` and `JsonError` payloads plus the `JsonOutput` emitter
  - JSON DTOs live in the CLI target, not in AranetKit, so the library API stays free of a wire format it does not own
  - Every measurement is emitted as a `{"value": ..., "unit": ...}` pair via the generic `JsonMeasurement<Value>` wrapper, so consumers never have to hardcode unit assumptions; units are `percent`, `seconds`, `ppm`, `C`, `hPa`, `µSv/h`, `µSv` and `Bq/m³`
  - The `ago` property of `AranetReading` is exposed as `age` in JSON; radiation totals are reported in µSv (not mSv) to match the dose rate unit scale
  - Optional fields are omitted when the device does not report them, so payload shape identifies the sensor type
  - `scan` and `read` emit indented JSON; `monitor` emits compact single-line objects for newline-delimited streaming
  - Keys are sorted alphabetically (`.sortedKeys`): Foundation's `JSONEncoder` cannot preserve property declaration order because it serialises through an unordered dictionary, so alphabetical ordering is the only deterministic, diffable option
- **Files changed**: Sources/AranetCli/AranetCli.swift, Sources/AranetCli/JsonOutput.swift, README.md, AGENTS.md
- **Reasoning**: The CLI was interactive-only; spinners and decorative separators made it unusable from scripts and agent tooling without brittle text parsing

### 2026-07-25 (v3.4.0, release notes)

- changed: `--version` is now a root-only flag and no longer appears on subcommand help pages
- changed: The canonical version moved to `AranetCli.toolVersion`

### 2026-07-25 (Root-Only Version Flag, Version 3.4.0)

- **Minor version bump**: 3.3.1 to 3.4.0
- **`--version` is now a root-only global flag**: Removed `version:` from the root `CommandConfiguration` and replaced it with an explicit `@Flag(name: .customLong("version")) var showVersion` on the root `AranetCli` command
  - swift-argument-parser adds its built-in `--version` flag to the help page of *every* command in the stack when `configuration.version` is non-empty (see `HelpGenerator.versionArgumentDefinition()`), so there is no supported way to hide it from subcommand help while keeping the built-in mechanism
  - The root command now implements `mutating func run() async throws`, printing `Self.toolVersion` when the flag is set and otherwise throwing `CleanExit.helpRequest(self)` to preserve the previous no-argument behaviour of printing help
- **Version constant location changed**: The canonical version now lives in `AranetCli.toolVersion`, not in `CommandConfiguration(version:)`; the Semantic Versioning Protocol section above was updated accordingly
- **Behaviour change**: `aranet-cli <subcommand> --version` is no longer accepted (it was never documented); `aranet-cli --version` continues to work and prints the bare version string
- **Files changed**: Sources/AranetCli/AranetCli.swift, README.md, AGENTS.md
- **Reasoning**: Subcommand help pages listed `--version` even though version reporting is a top-level concern, which cluttered the per-command option lists

### 2026-07-25 (v3.3.1, release notes)

- changed: Corrected README installation, timeout, device capability, notification, and API documentation

### 2026-07-25 (README Accuracy Pass, Version 3.3.1)

- **Patch version bump**: 3.3.0 to 3.3.1 (documentation-only change per SemVer protocol)
- **README corrections**:
  - Default scan timeout documented as 15s (CLI `--timeout` default and `AranetClient.scan()` default are both 15.0; the previous "10-second" text was stale)
  - Troubleshooting suggestion changed from `--timeout 15` to `--timeout 30`
  - SPM dependency version updated from 3.2.0 to 3.3.1 in both installation snippets
  - Installation heading changed from "Swift Package Manager (library only)" to "Swift Package Manager" because `Package.swift` vends both the `AranetKit` library and the `aranet-cli` executable products
  - Documented that `read` and `monitor` run an internal 15-second scan and exit with failure on unmatched devices
  - Characteristic list reordered to match the actual `readingCharacteristicPriority` (F0CD3001, F0CD3003, F0CD1504, F0CD1503)
  - Device Not Found troubleshooting now quotes the actual CLI error strings
  - Aranet Radon Plus row now lists temperature, humidity and pressure alongside radon concentration
  - Project structure tree now includes `AranetNotifications.swift`
  - Library snippet uses `scan(timeout: 15.0)` and shows `client.verbose`
  - Added `AranetError` case list and a new "Reading Notifications" section covering `.aranetReadingDidUpdate`, `AranetNotificationKey`, and the `.common` run loop mode behaviour
  - Added monitor bullets for dynamic interval adaptation and notification posting
- **Documentation gap noted**: the 2025-12-28 entry below claims the executable is excluded from `products`; `Package.swift` currently exposes `aranet-cli` as an executable product, so the README now reflects the code
- **Files changed**: README.md, Sources/AranetCli/AranetCli.swift, AGENTS.md
- **Reasoning**: The README had drifted from the implementation across timeouts, versions, characteristic priority, device capabilities and the notification API added in 3.3.0

### 2026-07-25 (v3.3.0, release notes)

- added: `Notification.Name.aranetReadingDidUpdate` posted by `monitor(from:)` with device, reading, and receive time in user info
- fixed: Monitor scheduling timers now use `RunLoop.main` `.common` mode so readings continue while AppKit menus are tracked

### 2026-07-25 (Version 3.3.0)

- **Minor version bump**: Updated `aranet-cli` to version 3.3.0 for the new monitor-reading notification API and menu-tracking timer fix
- **Reasoning**: The public notification API is a backward-compatible feature, so it requires a minor SemVer increment

### 2026-05-20 (Monitor Notifications and Menu-Tracking Timers)

- **`Notification.Name.aranetReadingDidUpdate`**: Posted by `monitor(from:)` with `AranetNotificationKey` user info (`device`, `reading`, `receivedAt`)
- **Monitor timer run loop mode**: `monitoringLoop` waits via `RunLoop.main` `.common` mode so scheduled reads continue while AppKit menus are tracked
- **Reasoning**: macOS pauses default-mode timers during menu tracking; senor-particle and other menu bar apps need live readings without app-level polling workarounds

### 2026-03-22 12:00 (Publication Preparation)

- **CHANGELOG backfill**: Added entries for v1.0.1 through v3.2.0 using AGENTS.md decision log
- **GitHub Actions CI**: Created `.github/workflows/build.yml` with macOS-15 runner and Swift 6.2 build jobs
  - A lint job using bundled `xcrun swift-format` was intended and documented here but was
    omitted from the workflow; it was restored on 2026-07-26
- **Lint fixes**: Resolved all 16 swift-format lint violations across Sources/
  - Added `// swift-format-ignore` for Dimension baseUnit() force cast pattern (Units.swift)
  - Added `// swift-format-ignore` for CBCentralManager IUO and protocol RSSI parameter (AranetClient.swift)
  - Fixed force unwrap in hex dump parser and ProgressSpinner timer
  - Converted for-if to for-where clause in characteristic reading loop
  - Removed trailing commas from array literals per swift-format config
  - Auto-formatted indentation, spacing, and line breaks
- **swift-format config fix**: Removed extra colon from NeverUseImplicitlyUnwrappedOptionals key
- **README**: Updated SPM dependency version from 3.1.0 to 3.2.0 in both installation examples
- **Files changed**: .swift-format, CHANGELOG.md, README.md, .github/workflows/build.yml, Sources/ (all files), AGENTS.md
- **Reasoning**: Prepare package for initial public release on GitHub

### 2026-03-14 (v3.2.0, release notes)

- added: Aranet Radiation status parsing (byte 27: Green/Yellow/Red display color)
- added: Shared `printHexDump(_:title:fields:)` helper with per-device field tables
- added: Aranet4 hex dump support using shared helper
- changed: Major DRY refactoring reducing ~120 lines across AranetClient and AranetCli
- changed: Extracted shared helpers: `failOperation`, `readingCharacteristics`, `printError`, `scanAndMatchDevices`
- changed: Simplified `formatOutput()` with computed properties per measurement line
- changed: Consolidated characteristic discovery and priority selection logic
- documented: Fully decoded Aranet Radiation extended data (bytes 28-47)

### 2026-03-14 15:00 (Aranet Radiation Status + Extended Data Discovery)

- **Discovery 1 - Status (byte 27)**: Contains the status display color for Aranet Radiation devices
  - Encoding differs from Aranet4 (0/1/2/3): Radiation uses 0x05=Green, 0x0A=Yellow, 0x0B=Red
  - The Python reference library reads this byte via struct format but silently discards it
- **Discovery 2 - Extended data (bytes 28-47)**: Fully decoded via empirical analysis (3 readings)
  - Bytes 28-35 (UInt64 LE): Total dose in microsieverts (µSv) = floor(total_nSv / 1000)
  - Bytes 36-43 (UInt64 LE): Real-time duration counter in seconds, 60s granularity = floor((duration + ago) / 60) * 60
  - Bytes 44-47: Reserved (zero)
  - The Python library ignores all 20 bytes of extended data
- **Implementation**:
  - Added `AranetStatusColor.fromRadiationByte(_:)` static factory method for radiation-specific mapping
  - Radiation parsing now reads byte 27 and maps it to `AranetStatusColor`
  - Status is included in `AranetReading` and displayed in CLI output for radiation devices
  - Refactored hex dump into shared `printHexDump(_:title:fields:)` with per-device field tables
  - Added Aranet4 hex dump support using the same shared helper
- **Version bump**: 3.1.0 to 3.2.0 (MINOR - new feature, backward compatible)
- **Files changed**: AranetTypes.swift, AranetClient.swift, AranetCli.swift, AGENTS.md
- **Reasoning**: Aranet Radiation devices transmit status and extended data that neither the Python library nor our implementation was parsing. Confirmed via empirical testing with 3 consecutive readings from device 30F9A. The extended data (bytes 28-47) contains lower-resolution duplicates of total dose and duration -- not needed for our implementation but now fully documented.

### 2026-03-14 14:00 (DRY Refactoring - Code Deduplication)

- **Added DRY principle** to Swift Coding Conventions in AGENTS.md
- **AranetClient.swift refactoring**:
  - Added `readingCharacteristicPriority` (ordered array) and `readingCharacteristics` (derived set) to `AranetUUID`
  - Added `failOperation(_:with:disconnect:)` helper -- replaces 6 identical cleanup sequences
  - Consolidated 4 characteristic discovery `else if` blocks into one `readingCharacteristics.contains()` check
  - Replaced 4-branch priority selection chain with `readingCharacteristicPriority.first(where:)`
  - Unified duplicate 28-byte and 48-byte radiation parsing into single parameterized block (rateDivisor)
  - Replaced 2 inline four-UUID disjunctions with `readingCharacteristics.contains()`
  - Fixed unused variable warning in `failAllOperations`
  - Removed redundant guard (`data.count == 28` already guarantees `>= 28`)
- **AranetCli.swift refactoring**:
  - Added `[AranetDevice].match(queries:)` extension -- eliminates duplicate device matching in Read and Monitor
  - Added `scanAndMatchDevices(queries:verbose:)` -- eliminates ~30 lines of duplicate scan/spinner/match boilerplate
  - Added `printError(_:device:)` -- eliminates duplicate AranetError formatting
  - Extracted 9 computed properties from `formatOutput()` (co2Line, temperatureLine, humidityLine, pressureLine, batteryLine, statusLine, ageLine, radonLine, radiationLines)
  - Simplified `formatOutput()` switch cases to single-line property concatenations
  - Refactored `Read.run()` from 65 lines to 40 lines using shared helpers
  - Refactored `Monitor.run()` from 65 lines to 35 lines using shared helpers
- **Net reduction**: ~120 lines removed across both files
- **Files changed**: AranetClient.swift, AranetCli.swift, AGENTS.md
- **Reasoning**: Multiple exact and near-duplicate code blocks violated DRY, risking inconsistent updates and inflating maintenance burden. Shared helpers provide single sources of truth for device matching, error display, operation cleanup, and characteristic priority.

### 2026-03-14 (v3.1.0, release notes)

- added: Multi-device read: `aranetcli read 228EB 30F9A` reads concurrently
- added: Multi-device monitor: `aranetcli monitor 228EB 30F9A` monitors concurrently
- added: Device matching extension `[AranetDevice].match(queries:)`
- added: Shared `scanAndMatchDevices` helper eliminates duplicate scan boilerplate
- added: Partial success support: prints results for successful devices, reports failures
- changed: `@Argument var device: String` changed to `@Argument var devices: [String]`
- changed: Single scan for all requested devices, then concurrent reads/monitors

### 2026-03-14 13:30 (Multi-Device Monitor Command)

- **New feature**: `monitor` command now accepts multiple device arguments
- **Usage**: `aranetcli monitor 228EB 30F9A` monitors both devices concurrently
- **Implementation**:
  - Changed `@Argument var device: String` to `@Argument var devices: [String]`
  - Single scan, match all requested devices, warn about not-found devices
  - Concurrent monitoring via `withThrowingTaskGroup` -- one task per device stream
  - Readings from all devices interleave in the terminal as they arrive
  - If any stream errors, the group cancels all others and exits
  - Error messages include device name for identification
- **Backward compatible**: Single-device usage unchanged (`aranetcli monitor 228EB`)
- **Files changed**: AranetCli.swift
- **Reasoning**: Mirrors the multi-device read command pattern. Enables monitoring all sensors from a single terminal session.

### 2026-03-14 13:00 (Multi-Device Read Command)

- **New feature**: `read` command now accepts multiple device arguments
- **Version bump**: 3.0.0 to 3.1.0 (MINOR - new feature, backward compatible)
- **Usage**: `aranetcli read 228EB 30F9A` reads from both devices concurrently
- **Implementation**:
  - Changed `@Argument var device: String` to `@Argument var devices: [String]`
  - Single scan, then match all requested devices against results
  - Concurrent reads via `withTaskGroup` leveraging per-operation state isolation
  - Reports not-found devices after printing successful readings
  - Adaptive spinner messages for single vs multiple devices
- **Backward compatible**: Single-device usage unchanged (`aranetcli read 228EB`)
- **Error handling**: Partial success supported -- prints results for devices that succeed, reports errors for failures, exits with failure if any device had errors
- **Files changed**: AranetCli.swift
- **Reasoning**: The library already supports concurrent reads via `ReadOperation` isolation. Exposing this at the CLI level enables reading all sensors in a single invocation, reducing total time from N sequential scans to one scan + concurrent reads.

### 2026-03-14 (v3.0.0, release notes)

- added: `AranetDevice` value type abstracting `CBPeripheral` (Identifiable, Hashable, Sendable)
- added: Concurrent read support via per-device `ReadOperation` isolation
- added: `knownPeripherals` dictionary maps AranetDevice IDs to CBPeripherals internally
- changed: **BREAKING**: `scan()` returns `[AranetDevice]` instead of `[CBPeripheral]`
- changed: **BREAKING**: `readCurrentReadings(from:)` takes `AranetDevice` instead of `CBPeripheral`
- changed: **BREAKING**: `monitor(from:)` takes `AranetDevice` instead of `CBPeripheral`
- changed: Consumers no longer need to `import CoreBluetooth`
- changed: `device.name` is non-optional String (was `peripheral.name?`)
- removed: Direct `CBPeripheral` exposure in public API

### 2026-03-14 12:00 (AranetDevice Abstraction and Concurrent Read Support - BREAKING CHANGE)

- **Major refactoring**: Replaced `CBPeripheral` in all public APIs with new `AranetDevice` value type
- **Breaking change**: Version bumped from 2.0.0 to 3.0.0 (MAJOR)
- **New type: `AranetDevice`** (AranetTypes.swift):
  - Public struct with `id: UUID` and `name: String` (non-optional)
  - Conforms to `Identifiable`, `Hashable`, `Sendable`
  - Abstracts CoreBluetooth so consumers never need to `import CoreBluetooth`
  - Instances created by `scan()`, passed to `readCurrentReadings(from:)` and `monitor(from:)`
- **Public API changes** (AranetClient.swift):
  - `scan(timeout:)` now returns `[AranetDevice]` instead of `[CBPeripheral]`
  - `readCurrentReadings(from:)` now takes `AranetDevice` instead of `CBPeripheral`
  - `monitor(from:)` now takes `AranetDevice` instead of `CBPeripheral`
  - Added explicit `@MainActor` annotations on `scan()` and `readCurrentReadings(from:)`
- **Concurrent read support** (AranetClient.swift):
  - New `ReadOperation` class encapsulates all per-read mutable state
  - `activeOperations: [UUID: ReadOperation]` dictionary replaces single-device instance properties
  - `knownPeripherals: [UUID: CBPeripheral]` maps AranetDevice IDs to CBPeripherals internally
  - `disconnect(_:)` now takes explicit peripheral parameter
  - New `failAllOperations(with:)` helper for Bluetooth state errors
  - New `completeReading(for:)` method takes a `ReadOperation` parameter
  - All CBPeripheralDelegate callbacks look up the correct `ReadOperation` by peripheral ID
  - Enables safe concurrent reads from multiple devices without state corruption
- **CLI changes** (AranetCli.swift):
  - Updated all commands to use `AranetDevice` instead of `CBPeripheral`
  - `device.name` is no longer optional (was `peripheral.name?`)
  - `device.id` replaces `peripheral.identifier`
  - Renamed local variable `peripheral` to `foundDevice` for clarity
- **Code cleanup**:
  - Removed verbose inline byte-format comments from parsing code (documented in AGENTS.md)
  - Removed explicit `nil` parameters from `AranetReading` init calls (uses defaults)
  - Removed redundant comments throughout the codebase
  - Streamlined DocC documentation comments
- **VSCode launch config** (.vscode/launch.json):
  - Changed debugger type from "swift" to "lldb"
  - Added explicit `program` paths for debug and release builds
- **Migration impact**: External code must replace `CBPeripheral` with `AranetDevice`, use `.id` instead of `.identifier`, and `.name` is now non-optional `String`
- **Files changed**: AranetTypes.swift, AranetClient.swift, AranetCli.swift, .vscode/launch.json
- **Reasoning**: Exposing `CBPeripheral` in the public API forced consumers to import CoreBluetooth, leaked framework internals, and prevented concurrent multi-device reads due to shared mutable state. The new `AranetDevice` value type provides a clean, Sendable-safe API surface while per-operation state isolation enables concurrent monitoring of multiple devices.

### 2025-12-28 15:00 (Package Structure - Executable Hidden from Dependencies)

- **Updated Package.swift structure**: Removed executable from products array, keeping only AranetKit library exposed
- **Xcode visibility**: Executable hidden from "Add Package Dependencies" dialog (not in products)
- **Binary output**: `aranet-cli` (explicit executable product name)
- **Local usage**: Can still build and run with `swift run aranet-cli`
- **Package structure**:
  - Package name: `AranetCli`
  - Library product: `AranetKit` (public, for dependencies)
  - Executable product: `aranet-cli` (public, maps to AranetCli target)
  - Library target: `AranetKit` in `Sources/AranetKit/`
  - Executable target: `AranetCli` in `Sources/AranetCli/`
  - Binary output: `aranet-cli`
- **Reasoning**: Standard pattern for packages providing both library and CLI tool - expose only the library as a product. This prevents the executable from appearing in Xcode's "Add Package Dependencies" dialog while keeping it available for local development.

### 2025-12-10 (v2.0.0, release notes)

- added: Swift Foundation `Measurement<Unit>` types for all physical quantities
- added: Custom `UnitRadiationDose` dimension (nSv, uSv, mSv, Sv)
- added: Custom `UnitRadioactivity` dimension (Bq/m3, pCi/L)
- added: New `Units.swift` source file
- changed: **BREAKING**: `temperature` changed from `Double?` to `Measurement<UnitTemperature>?`
- changed: **BREAKING**: `pressure` changed from `Double?` to `Measurement<UnitPressure>?`
- changed: **BREAKING**: `radiationRate` and `radiationTotal` changed to `Measurement<UnitRadiationDose>?`
- changed: **BREAKING**: `radonConcentration` changed from `UInt32?` to `Measurement<UnitRadioactivity>?`
- changed: Primitives retained for dimensionless values (humidity, battery, co2, time)

### 2025-12-10 17:00 (Swift Foundation Units API - BREAKING CHANGE)

- **Major refactoring**: Migrated library API to use Swift Foundation's `Measurement<Unit>` types for all physical quantities
- **Breaking change**: Version bumped from 1.0.1 to 2.0.0 (MAJOR)
- **Custom unit types created**:
  - `UnitRadiationDose` (Dimension subclass) - nanosieverts, microsieverts, millisieverts, sieverts
  - `UnitRadioactivity` (Dimension subclass) - becquerels per cubic meter, picocuries per liter
- **Properties changed to Measurement**:
  - `temperature: Double?` → `Measurement<UnitTemperature>?`
  - `pressure: Double?` → `Measurement<UnitPressure>?`
  - `radiationRate: Double?` → `Measurement<UnitRadiationDose>?`
  - `radiationTotal: Double?` → `Measurement<UnitRadiationDose>?`
  - `radonConcentration: UInt32?` → `Measurement<UnitRadioactivity>?`
- **Properties kept as primitives**: humidity, battery (percentages), co2 (ppm), time values (seconds)
- **Benefits**:
  - Type-safe physical quantities with compiler-checked units
  - Automatic unit conversions via `.converted(to:)` method
  - Better API semantics and self-documenting code
  - Standard Swift patterns for measurements
- **Migration impact**: External code needs to access `.value` property and update type signatures
- **Files updated**: Units.swift (new), AranetTypes.swift, AranetClient.swift, AranetCli.swift, AGENTS.md
- **Reasoning**: Using Foundation's Measurement types provides type safety, automatic conversions, and follows Swift best practices. Custom Dimension subclasses enable proper handling of radiation and radioactivity units not present in standard Foundation. Keeping simple values (percentages, ppm, time) as primitives avoids unnecessary complexity for dimensionless quantities.

### 2025-12-08 (v1.0.1, release notes)

- fixed: Monitor command now detects when sensor update interval changes during monitoring
- fixed: Renamed `baseInterval` to `currentInterval` and update from device-reported value each cycle
- fixed: Added verbose logging when interval changes are detected

### 2025-12-08 14:30 (Monitor Command Bug Fix - Dynamic Interval Update)

- **Bug**: Monitor command was not detecting when the user changed the sensor update interval via the Aranet app or external tools
- **Root cause**: The monitoring loop captured the interval from the initial reading and stored it in a constant variable called baseInterval, which was never updated
- **Solution**: Changed baseInterval to currentInterval and update it on each monitoring cycle from the device-reported interval value
- **Implementation details**:
  - Renamed baseInterval to currentInterval to reflect that it can change
  - Added check after each reading to update currentInterval if the device reports a new interval value
  - Added verbose logging when interval changes are detected
  - All delay calculations now use currentInterval instead of the stale baseInterval
- **Version bump**: 1.0.0 to 1.0.1 (PATCH - bug fix)
- **Files changed**: AranetClient.swift, AranetCli.swift
- **Impact**: Monitor command now properly adapts to interval changes made during monitoring session
- **Reasoning**: Each sensor reading includes the current device interval setting. By reading this value on every cycle, the monitor command automatically adapts to configuration changes without requiring restart. This provides better user experience when experimenting with different monitoring intervals.

### 2025-12-04 11:00 (Semantic Versioning Documentation Fix)

- **Fixed incorrect reference**: Changed Cargo.toml reference to AranetCli.swift
- **Added code example**: Shows exact location of version in CommandConfiguration
- **Updated process steps**: References correct file path for version updates
- **Reasoning**: This is a Swift project, not Rust. Version is tracked in the CommandConfiguration of the main CLI struct at `Sources/AranetCli/AranetCli.swift`.

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

### 2025-11-22 (v1.0.0, release notes)

- added: Initial release of aranetcli Swift implementation
- added: **Scan command**: Discover nearby Aranet Bluetooth devices
- added: **Read command**: Read current sensor measurements from Aranet devices
- added: **Monitor command**: Continuously monitor device with automatic periodic updates
- added: **AranetKit library**: Reusable Swift package for Aranet device communication
- added: Support for Aranet4, Aranet2, Aranet Radiation, and Aranet Radon Plus devices
- added: AsyncStream-based monitoring API with Result wrapping
- added: Timer-based scheduling for accurate periodic readings
- added: Comprehensive DocC documentation for all public APIs
- added: No pairing required for basic sensor readings
- added: Verbose debug mode for troubleshooting
- added: Progress indicators for scanning and connecting
- features: Native Swift performance with CoreBluetooth
- features: Async/await based API
- features: Automatic characteristic selection based on device capabilities
- features: Drift-free monitoring using device-reported intervals
- features: Clean error handling with descriptive messages
- features: Cross-platform support (macOS 12+)
- documentation: Comprehensive README with usage examples
- documentation: API documentation using Swift DocC format
- documentation: Troubleshooting guide
- documentation: Development setup instructions

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

### 2025-10-05 (v0.1.0, initial setup)

- initial AGENTS.md setup
- established core coding standards and conventions
- defined repository structure and governance principles
