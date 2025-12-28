# AranetKit & CLI

A Swift command-line tool for interacting with Aranet Bluetooth sensors (Aranet4, Aranet2, Aranet Radiation, Aranet Radon Plus).

## Features

- **Scan** for nearby Aranet devices
- **Read** current sensor measurements (CO2, temperature, humidity, pressure, battery)
- **Monitor** sensor values with automatic periodic updates
- **Swift Foundation Units** - Type-safe measurements with automatic unit conversions
- **Progress indicators** - Visual feedback during scanning and connecting
- **No pairing required** - reads directly from BLE characteristics
- Native Swift performance with CoreBluetooth
- Async/await based API
- Cross-platform support (macOS, with iOS/iPadOS support possible)

## Requirements

- macOS 12.0 or later
- Xcode Command Line Tools or Xcode 14+
- Swift 6.2+
- Bluetooth enabled

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/heikopanjas/aranet-kit.git", from: "2.0.0")
]
```

### Build from source

```bash
git clone https://github.com/heikopanjas/aranet-kit.git
cd aranet-kit
swift build -c release
```

The compiled binary will be at `.build/release/aranetcli`

### Run directly with Swift

```bash
swift run aranetcli <command>
```

## Usage

### Scan for devices

Scan for nearby Aranet devices:

```bash
# Default 5-second scan
swift run aranetcli scan

# Custom timeout
swift run aranetcli scan --timeout 10
```

Example output:

```text
Scanning for Aranet devices...
Found 1 device(s):

1. Aranet4 228EB (A1B2C3D4-E5F6-7890-A1B2-C3D4E5F67890)
```

### Read sensor values

Read current measurements from a specific device:

```bash
# By device name (partial match)
swift run aranetcli read "Aranet4"

# By UUID
swift run aranetcli read "A1B2C3D4-E5F6-7890-A1B2-C3D4E5F67890"
```

Example output:

```text
Scanning for device 'Aranet4'...
Connecting to Aranet4 228EB...
---------------------------------------
Connected: Aranet4 228EB | v1.4.19
Updated 237 s ago. Intervals: 300 s
---------------------------------------
CO2:          1369 ppm
Temperature:  24.1 °C
Humidity:     44 %
Pressure:     1008.5 hPa
Battery:      94 %
Status Display: YELLOW
Age:          237/300 s
---------------------------------------
```

### Monitor sensor values

Continuously monitor a device with automatic periodic updates:

```bash
# Monitor by device name
swift run aranetcli monitor "Aranet4"

# Monitor with verbose output
swift run aranetcli monitor "Aranet4" --verbose
```

The monitor command:

- Performs an initial reading to get device interval and timing
- Calculates when the next sensor update will occur
- Schedules readings 3 seconds after each sensor update
- Continues monitoring until interrupted (Ctrl+C)

Example output:

```text
Scanning for device 'Aranet4'...
Connecting to Aranet4 228EB...
---------------------------------------
Connected: Aranet4 228EB | v1.4.19
Updated 237 s ago. Intervals: 300 s
---------------------------------------
CO2:          1369 ppm
Temperature:  24.1 °C
Humidity:     44 %
Pressure:     1008.5 hPa
Battery:      94 %
Status Display: YELLOW
Age:          237/300 s
---------------------------------------

Monitoring started. Press Ctrl+C to stop.
Next reading in approximately 78 seconds...

2025-11-22 20:30:45
---------------------------------------
Connected: Aranet4 228EB | v1.4.19
Updated 15 s ago. Intervals: 300 s
---------------------------------------
CO2:          1365 ppm
Temperature:  24.2 °C
Humidity:     43 %
Pressure:     1008.6 hPa
Battery:      94 %
Status Display: YELLOW
Age:          15/300 s
---------------------------------------
```

## Technical Details

### No Pairing Required

Unlike many Bluetooth devices, **Aranet4 sensors do not require pairing** for basic sensor readings. The tool reads from the "detailed" BLE characteristic (F0CD3001) which provides all sensor data without authentication.

### Characteristics Used

- **F0CD3001** (Detailed Current Readings) - Primary, no pairing required ✓
- **F0CD3003** (AR2 Detailed) - For Aranet Radiation, no pairing required ✓
- **F0CD1503** (Basic Current Readings) - Requires pairing/authentication
- **F0CD1504** (AR2 Current Readings) - For Aranet2 devices

The tool automatically selects the best available characteristic based on device type and availability.

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

If you get "Error: Device not found":

1. Run `swift run aranetcli scan` first to see available devices
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
3. Try increasing the scan timeout: `swift run aranetcli scan --timeout 15`
4. Check if the device is already connected to another application

## Supported Devices

- **Aranet4** - CO2, temperature, humidity, pressure
- **Aranet2** - Temperature, humidity (partial support)
- **Aranet Radiation** - Radiation measurements (partial support)
- **Aranet Radon Plus** - Radon concentration (partial support)

## Development

### Project Structure

```text
Sources/
├── AranetKit/           # Reusable library
│   ├── AranetClient.swift   # CoreBluetooth client
│   ├── AranetTypes.swift    # Data models and types
│   └── Units.swift          # Custom measurement units
└── AranetCli/           # CLI application
    ├── AranetCli.swift      # CLI interface
    └── ProgressSpinner.swift # Terminal UI utilities
```

### Using AranetKit as a Library

The core Bluetooth functionality is available as a Swift package that can be imported into your own projects:

```swift
// In your Package.swift
dependencies: [
    .package(url: "https://github.com/heikopanjas/aranet-kit.git", from: "2.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AranetKit"]
    )
]

// In your Swift code
import AranetKit

let client = AranetClient()

// Scan for devices
let devices = try await client.scan(timeout: 5.0)

// Read sensor data
if let device = devices.first {
    let reading = try await client.readCurrentReadings(from: device)
    
    // Access measurements with type-safe units
    print("CO2: \(reading.co2 ?? 0) ppm")
    
    if let temp = reading.temperature {
        print("Temperature: \(temp.value)°C")
        // Convert to Fahrenheit
        let tempF = temp.converted(to: .fahrenheit)
        print("Temperature: \(tempF.value)°F")
    }
    
    if let pressure = reading.pressure {
        print("Pressure: \(pressure.value) hPa")
        // Convert to inches of mercury
        let pressureInHg = pressure.converted(to: .inchesOfMercury)
        print("Pressure: \(pressureInHg.value) inHg")
    }
}

// Monitor sensor values continuously
let monitorStream = await client.monitor(from: device)
for await result in monitorStream {
    switch result {
    case .success(let reading):
        print("New reading: \(reading.co2 ?? 0) ppm CO2")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Building for Development

```bash
# Build debug version
swift build

# Run tests
swift test

# Build release version
swift build -c release
```

## License

MIT License (inherited from the Python implementation)

## Credits

Based on the Python [aranet4](https://github.com/Anrijs/Aranet4-Python) library by Anrijs Jargans.

## Related Projects

- [aranet4-python](https://github.com/Anrijs/Aranet4-Python) - Original Python implementation
- [Aranet Home App](https://aranet.com/aranet-home-app) - Official mobile application
