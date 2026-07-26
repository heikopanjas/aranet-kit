# AranetKit & aranet-cli

[![Build](https://github.com/heikopanjas/aranet-kit/actions/workflows/build.yml/badge.svg)](https://github.com/heikopanjas/aranet-kit/actions/workflows/build.yml)

A Swift command-line tool and library for interacting with Aranet Bluetooth sensors (Aranet4, Aranet2, Aranet Radiation, Aranet Radon Plus).

## Features

- **Scan** for nearby Aranet devices
- **Read** current sensor measurements from one or more devices concurrently
- **Monitor** sensor values with automatic periodic updates (single or multi-device)
- **JSON mode** - `--json` for scripts and agents: data only, no progress output
- **Notifications** - `NotificationCenter` broadcasts for every monitored reading
- **Swift Foundation Units** - Type-safe measurements with automatic unit conversions
- **No CoreBluetooth required** - library API uses pure Swift value types (`AranetDevice`)
- **Progress indicators** - Visual feedback during scanning and connecting
- **No pairing required** - reads directly from BLE characteristics
- Native Swift performance with async/await API
- Cross-platform support (macOS, with iOS/iPadOS support possible)

## Requirements

- macOS 12.0 or later
- Xcode Command Line Tools or Xcode 14+
- Swift 6.2+
- Bluetooth enabled

## Installation

### Download pre-built binary

Download `aranet-cli-<version>-macos-arm64.tar.gz` and `SHA256SUMS.txt` from the
[latest GitHub release](https://github.com/heikopanjas/aranet-kit/releases/latest).
The pre-built, signed and notarized executable supports Apple Silicon Macs only. Intel
Mac users must [build from source](#build-from-source).

```bash
grep macos-arm64 SHA256SUMS.txt | shasum -a 256 -c -
tar -xzf aranet-cli-<version>-macos-arm64.tar.gz
cd aranet-cli-<version>-macos-arm64
chmod +x aranet-cli
sudo mv aranet-cli /usr/local/bin/
```

### Swift Package Manager

The package vends two products: the `AranetKit` library and the `aranet-cli` executable.
To use the library in your own project, add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/heikopanjas/aranet-kit.git", from: "3.5.1")
]
```

`AranetKit` is distributed as source through each release tag. Releases also contain an
arm64 executable artifact bundle for build tools that consume SwiftPM binary targets;
the matching `.binaryTarget` declaration and checksum are included in the release notes.

### Build from source

```bash
git clone https://github.com/heikopanjas/aranet-kit.git
cd aranet-kit
swift build -c release
```

Find the compiled binary with `swift build -c release --show-bin-path`.

## Usage

> **Note:** The examples below use `aranet-cli` directly (assuming the binary is installed).
> If running from source, replace `aranet-cli` with `swift run aranet-cli`.

### Scan for devices

Scan for nearby Aranet devices:

```bash
# Default 15-second scan
aranet-cli scan

# Custom timeout
aranet-cli scan --timeout 30

# Verbose output
aranet-cli scan --verbose
```

> **Note:** Aranet devices advertise infrequently to conserve battery. A longer timeout
> increases the chance of discovering all nearby devices.

Example output:

```text
Found 2 device(s):

1. Aranet4 228EB (B6F33CE5-4712-5841-C308-B4217CDAFD68)
2. Aranet☢ 30F9A (DBE557A0-322A-26CA-777F-26EE338250B4)
```

### Read sensor values

Read current measurements from one or more devices:

```bash
# Single device by name (partial match)
aranet-cli read 228EB

# Multiple devices at once (concurrent reads)
aranet-cli read 228EB 30F9A

# By UUID
aranet-cli read "B6F33CE5-4712-5841-C308-B4217CDAFD68"

# Verbose output
aranet-cli read 228EB --verbose
```

The `read` and `monitor` commands perform an internal 15-second scan before connecting.
Devices that cannot be matched are reported after the successful readings, and the
command exits with a failure status if any device errored or was not found.

Example output (multi-device):

```text
---------------------------------------
Connected: Aranet4 228EB | v1.4.19
Updated 83s ago. Intervals: 300s
---------------------------------------
CO2:          1683 ppm
Temperature:  22.8 °C
Humidity:     45 %
Pressure:     995.0 hPa
Battery:      92 %
Status Display: RED
Age:          83s/300s
---------------------------------------
---------------------------------------
Connected: Aranet☢ 30F9A | v1.9.5
Updated 273s ago. Intervals: 300s
---------------------------------------
Dose rate:    0.14 µSv/h
Dose total:   0.1994 mSv/108d 1h 32m
Battery:      94 %
Age:          273s/300s
---------------------------------------
```

### Monitor sensor values

Continuously monitor one or more devices with automatic periodic updates:

```bash
# Monitor a single device
aranet-cli monitor 228EB

# Monitor multiple devices concurrently
aranet-cli monitor 228EB 30F9A

# Monitor with verbose output
aranet-cli monitor 228EB --verbose
```

The monitor command:

- Performs an initial reading to get device interval and timing
- Calculates when the next sensor update will occur
- Schedules readings 3 seconds after each sensor update
- Adapts automatically when the device interval is changed during a session
- Posts an `aranetReadingDidUpdate` notification for every reading
- Continues monitoring until interrupted (Ctrl+C)
- When monitoring multiple devices, readings interleave as they arrive

### Script and agent mode (`--json`)

All subcommands accept `--json`. In this mode the tool prints machine-readable data on
**stdout** -- errors included -- and nothing else: no spinners, banners or other progress
output. Verbose diagnostics are suppressed so stdout always stays parseable.

`--json` is a global flag listed in `aranet-cli --help`, and works before or after the
subcommand name:

```bash
# Devices as a JSON array
aranet-cli scan --json
aranet-cli --json scan

# Readings as a JSON array (one object per successfully read device)
aranet-cli read 228EB 30F9A --json

# Newline-delimited JSON, one object per reading, until interrupted
aranet-cli monitor 228EB --json
```

Scan output:

```json
[
  {
    "id" : "B6F33CE5-4712-5841-C308-B4217CDAFD68",
    "name" : "Aranet4 228EB"
  }
]
```

Reading output -- every measurement is a `value`/`unit` pair, and measurements the
device does not report are omitted:

```json
[
  {
    "age" : { "unit" : "seconds", "value" : 230 },
    "battery" : { "unit" : "percent", "value" : 89 },
    "co2" : { "unit" : "ppm", "value" : 1995 },
    "device" : "Aranet4 228EB",
    "deviceType" : "Aranet4",
    "firmwareVersion" : "v1.4.19",
    "humidity" : { "unit" : "percent", "value" : 56 },
    "interval" : { "unit" : "seconds", "value" : 300 },
    "pressure" : { "unit" : "hPa", "value" : 999.5 },
    "status" : "RED",
    "temperature" : { "unit" : "C", "value" : 23.95 },
    "timestamp" : "2026-07-25T16:17:52Z"
  }
]
```

A radiation sensor reports `radiationRate` (µSv/h), `radiationTotal` (µSv) and
`radiationDuration` (seconds) instead; a radon sensor reports `radonConcentration`
(Bq/m³). `scan` and `read` print indented JSON, while `monitor` prints one compact
JSON object per line so the stream can be consumed incrementally. Keys are sorted
alphabetically for deterministic, diffable output.

Errors are single-line JSON objects on **stdout**, and the exit status is non-zero.
This covers device and Bluetooth failures as well as argument parsing failures, so a
script never has to parse human-readable diagnostics:

```json
{"error":"No matching devices found"}
{"error":"Device 'kitchen' not found","device":"kitchen"}
{"error":"Unknown option '--bogus'"}
```

When some devices succeed and others fail, the data array is printed first, followed by
one error object per failure. Exit codes are unchanged: `1` for runtime failures, `64`
for usage errors. `--help` and `--version` keep their regular plain-text output.

## Technical Details

### No Pairing Required

Unlike many Bluetooth devices, **Aranet4 sensors do not require pairing** for basic sensor readings. The tool reads from the "detailed" BLE characteristic (F0CD3001) which provides all sensor data without authentication.

### Characteristics Used

Characteristics are tried in this priority order:

1. **F0CD3001** (Detailed Current Readings) - Aranet4, no pairing required ✓
2. **F0CD3003** (AR2 Detailed) - Aranet Radiation / Radon, no pairing required ✓
3. **F0CD1504** (AR2 Current Readings) - Aranet2 and AR2-family devices, requires pairing
4. **F0CD1503** (Basic Current Readings) - Aranet4 fallback, requires pairing

The tool discovers all characteristics first, then automatically selects the best available
one based on device type and availability.

### Swift Foundation Units

AranetKit uses Swift Foundation's `Measurement<Unit>` types for all physical quantities, providing:

- **Type-safe measurements** with compiler-checked units
- **Automatic unit conversions** via `.converted(to:)` method
- **Standard Foundation units**: Temperature (°C, °F, K), Pressure (hPa, inHg, bar)
- **Custom units for radiation**: Dose measurements (nSv, µSv, mSv, Sv)
- **Custom units for radon**: Concentration (Bq/m³, pCi/L)

All raw sensor values (percentages, ppm, time) remain as primitive types for simplicity.

## Troubleshooting

### Bluetooth Permission Denied

If you see "Bluetooth access is not authorized", grant Bluetooth permissions:

1. Go to **System Settings → Privacy & Security → Bluetooth**
2. Enable Bluetooth access for Terminal or your shell application

### Device Not Found

If you get "Error: No matching devices found" or "Error: Device '...' not found":

1. Run `aranet-cli scan` first to see available devices
2. Use the exact device name or UUID from the scan results
3. Device names are case-insensitive and support partial matching
4. Ensure the device is nearby and powered on

### Bluetooth Unavailable Error

If you see "Error: Bluetooth is unavailable or not ready", check:

1. **Bluetooth is enabled**: Go to System Settings → Bluetooth and ensure Bluetooth is turned on
2. **Terminal has Bluetooth permissions**:
   - Go to System Settings → Privacy & Security → Bluetooth
   - Ensure Terminal (or your IDE) is listed and enabled
3. **First run may require permission**: The first time you run the tool, macOS may prompt you to allow Bluetooth access

### Bluetooth Unauthorized Error

If you see "Error: Bluetooth access is not authorized":

1. Go to System Settings → Privacy & Security → Bluetooth
2. Find Terminal (or your development environment) in the list
3. Enable the checkbox next to it
4. Restart the terminal and try again

### No Devices Found

If scanning finds no devices:

1. Ensure your Aranet device is powered on and nearby
2. Make sure "Smart Home integrations" is enabled in the Aranet Home mobile app
3. Try increasing the scan timeout: `aranet-cli scan --timeout 30`
4. Check if the device is already connected to another application

## Supported Devices

| Device | Measurements | Status |
|--------|-------------|--------|
| [**Aranet4**](https://aranet.com/en/home/products/aranet4-home) | CO2, temperature, humidity, pressure | Fully supported |
| [**Aranet Radiation**](https://aranet.com/en/home/products/aranet-radiation-sensor) | Dose rate, cumulative dose, duration | Fully supported |
| [**Aranet2 HOME**](https://aranet.com/en/home/products/aranet2-home) | Temperature, humidity | Experimental, untested |
| [**Aranet Radon Plus**](https://aranet.com/en/home/products/aranet-radon-sensor) | Radon concentration, temperature, humidity, pressure | Experimental, untested |

## Development

### Project Structure

```text
Sources/
├── AranetKit/           # Reusable library
│   ├── AranetClient.swift        # CoreBluetooth client
│   ├── AranetNotifications.swift # NotificationCenter integration
│   ├── AranetTypes.swift         # Data models and types
│   └── Units.swift               # Custom measurement units
└── AranetCli/           # CLI application
    ├── AranetCli.swift       # CLI interface
    ├── JsonOutput.swift      # Machine-readable output (--json)
    └── ProgressSpinner.swift # Terminal UI utilities
```

### Using AranetKit as a Library

The core Bluetooth functionality is available as a Swift package that can be imported into your own projects:

```swift
// In your Package.swift
dependencies: [
    .package(url: "https://github.com/heikopanjas/aranet-kit.git", from: "3.5.1")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AranetKit"]
    )
]

// In your Swift code -- no CoreBluetooth import needed
import AranetKit

let client = AranetClient()
client.verbose = false

// Scan returns [AranetDevice] (pure Swift value types)
let devices = try await client.scan(timeout: 15.0)

// Read sensor data
if let device = devices.first {
    let reading = try await client.readCurrentReadings(from: device)

    // Access measurements with type-safe units
    print("CO2: \(reading.co2 ?? 0) ppm")

    if let temp = reading.temperature {
        print("Temperature: \(temp.value)°C")
        let tempF = temp.converted(to: .fahrenheit)
        print("Temperature: \(tempF.value)°F")
    }

    if let pressure = reading.pressure {
        print("Pressure: \(pressure.value) hPa")
        let pressureInHg = pressure.converted(to: .inchesOfMercury)
        print("Pressure: \(pressureInHg.value) inHg")
    }
}

// Monitor sensor values continuously
if let device = devices.first {
    let stream = await client.monitor(from: device)
    for await result in stream {
        switch result {
        case .success(let reading):
            print("New reading: \(reading.co2 ?? 0) ppm CO2")
        case .failure(let error):
            print("Error: \(error)")
        }
    }
}
```

Errors thrown by the client are `AranetError` values (`bluetoothUnavailable`,
`bluetoothUnauthorized`, `bluetoothUnsupported`, `deviceNotFound`, `connectionFailed`,
`readFailed`, `invalidData`, `timeout`, `pairingRequired`), each with a human-readable
`description`.

### Reading Notifications

Every reading delivered by `monitor(from:)` is also posted to `NotificationCenter`,
which is convenient for menu bar apps and other UI-driven consumers that do not want
to own the async stream:

```swift
import AranetKit

NotificationCenter.default.addObserver(
    forName: .aranetReadingDidUpdate,
    object: nil,
    queue: .main
) { notification in
    guard let device = notification.userInfo?[AranetNotificationKey.device] as? AranetDevice,
          let reading = notification.userInfo?[AranetNotificationKey.reading] as? AranetReading,
          let receivedAt = notification.userInfo?[AranetNotificationKey.receivedAt] as? Date
    else { return }

    print("\(device.name) at \(receivedAt): \(reading.co2 ?? 0) ppm")
}
```

The monitoring timer runs in the `.common` run loop mode, so readings keep arriving
while AppKit menus are being tracked.

### Building for Development

```bash
# Build debug version
swift build

# Build release version
swift build -c release

# Run from source
swift run aranet-cli scan
```

## License

MIT License (inherited from the Python implementation)

## Credits

Based on the Python [aranet4](https://github.com/Anrijs/Aranet4-Python) library by Anrijs Jargans.

## Related Projects

- [aranet4-python](https://github.com/Anrijs/Aranet4-Python) - Original Python implementation
- [Aranet Home App](https://aranet.com/aranet-home-app) - Official mobile application
