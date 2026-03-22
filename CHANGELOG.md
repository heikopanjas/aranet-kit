# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.2.0] - 2026-03-14

### Added

- Aranet Radiation status parsing (byte 27: Green/Yellow/Red display color)
- Shared `printHexDump(_:title:fields:)` helper with per-device field tables
- Aranet4 hex dump support using shared helper

### Changed

- Major DRY refactoring reducing ~120 lines across AranetClient and AranetCli
- Extracted shared helpers: `failOperation`, `readingCharacteristics`, `printError`, `scanAndMatchDevices`
- Simplified `formatOutput()` with computed properties per measurement line
- Consolidated characteristic discovery and priority selection logic

### Documented

- Fully decoded Aranet Radiation extended data (bytes 28-47)

## [3.1.0] - 2026-03-14

### Added

- Multi-device read: `aranetcli read 228EB 30F9A` reads concurrently
- Multi-device monitor: `aranetcli monitor 228EB 30F9A` monitors concurrently
- Device matching extension `[AranetDevice].match(queries:)`
- Shared `scanAndMatchDevices` helper eliminates duplicate scan boilerplate
- Partial success support: prints results for successful devices, reports failures

### Changed

- `@Argument var device: String` changed to `@Argument var devices: [String]`
- Single scan for all requested devices, then concurrent reads/monitors

## [3.0.0] - 2026-03-14

### Added

- `AranetDevice` value type abstracting `CBPeripheral` (Identifiable, Hashable, Sendable)
- Concurrent read support via per-device `ReadOperation` isolation
- `knownPeripherals` dictionary maps AranetDevice IDs to CBPeripherals internally

### Changed

- **BREAKING**: `scan()` returns `[AranetDevice]` instead of `[CBPeripheral]`
- **BREAKING**: `readCurrentReadings(from:)` takes `AranetDevice` instead of `CBPeripheral`
- **BREAKING**: `monitor(from:)` takes `AranetDevice` instead of `CBPeripheral`
- Consumers no longer need to `import CoreBluetooth`
- `device.name` is non-optional String (was `peripheral.name?`)

### Removed

- Direct `CBPeripheral` exposure in public API

## [2.0.0] - 2025-12-10

### Added

- Swift Foundation `Measurement<Unit>` types for all physical quantities
- Custom `UnitRadiationDose` dimension (nSv, uSv, mSv, Sv)
- Custom `UnitRadioactivity` dimension (Bq/m3, pCi/L)
- New `Units.swift` source file

### Changed

- **BREAKING**: `temperature` changed from `Double?` to `Measurement<UnitTemperature>?`
- **BREAKING**: `pressure` changed from `Double?` to `Measurement<UnitPressure>?`
- **BREAKING**: `radiationRate` and `radiationTotal` changed to `Measurement<UnitRadiationDose>?`
- **BREAKING**: `radonConcentration` changed from `UInt32?` to `Measurement<UnitRadioactivity>?`
- Primitives retained for dimensionless values (humidity, battery, co2, time)

## [1.0.1] - 2025-12-08

### Fixed

- Monitor command now detects when sensor update interval changes during monitoring
- Renamed `baseInterval` to `currentInterval` and update from device-reported value each cycle
- Added verbose logging when interval changes are detected

## [1.0.0] - 2025-11-22

### Added

- Initial release of aranetcli Swift implementation
- **Scan command**: Discover nearby Aranet Bluetooth devices
- **Read command**: Read current sensor measurements from Aranet devices
- **Monitor command**: Continuously monitor device with automatic periodic updates
- **AranetKit library**: Reusable Swift package for Aranet device communication
- Support for Aranet4, Aranet2, Aranet Radiation, and Aranet Radon Plus devices
- AsyncStream-based monitoring API with Result wrapping
- Timer-based scheduling for accurate periodic readings
- Comprehensive DocC documentation for all public APIs
- No pairing required for basic sensor readings
- Verbose debug mode for troubleshooting
- Progress indicators for scanning and connecting

### Features

- Native Swift performance with CoreBluetooth
- Async/await based API
- Automatic characteristic selection based on device capabilities
- Drift-free monitoring using device-reported intervals
- Clean error handling with descriptive messages
- Cross-platform support (macOS 12+)

### Documentation

- Comprehensive README with usage examples
- API documentation using Swift DocC format
- Troubleshooting guide
- Development setup instructions

[Unreleased]: https://github.com/heikopanjas/aranet-kit/compare/v3.2.0...HEAD
[3.2.0]: https://github.com/heikopanjas/aranet-kit/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/heikopanjas/aranet-kit/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/heikopanjas/aranet-kit/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/heikopanjas/aranet-kit/compare/v1.0.1...v2.0.0
[1.0.1]: https://github.com/heikopanjas/aranet-kit/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/heikopanjas/aranet-kit/releases/tag/v1.0.0
