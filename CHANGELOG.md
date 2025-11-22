# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/heikopanjas/aranet-kit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/heikopanjas/aranet-kit/releases/tag/v1.0.0
