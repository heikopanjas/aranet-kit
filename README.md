# aranetctl

A Swift command-line tool for interacting with Aranet Bluetooth sensors (Aranet4, Aranet2, Aranet Radiation, Aranet Radon Plus).

## Features

- **Scan** for nearby Aranet devices
- **Read** current sensor measurements (CO2, temperature, humidity, pressure, battery)
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

### Build from source

```bash
git clone <repository-url>
cd aranetctl
swift build -c release
```

The compiled binary will be at `.build/release/aranetctl`

### Run directly with Swift

```bash
swift run aranetctl <command>
```

## Usage

### Scan for devices

Scan for nearby Aranet devices:

```bash
# Default 5-second scan
swift run aranetctl scan

# Custom timeout
swift run aranetctl scan --timeout 10
```

Example output:
```
Scanning for Aranet devices...
Found 1 device(s):

1. Aranet4 228EB (B6F33CE5-4712-5841-C308-B4217CDAFD68)
```

Example output:

```text
Scanning for Aranet devices...
Found 1 device(s):

1. Aranet4 228EB (B6F33CE5-4712-5841-C308-B4217CDAFD68)
```

### Read sensor values

Read current measurements from a specific device:

```bash
# By device name (partial match)
swift run aranetctl read "Aranet4"

# By UUID
swift run aranetctl read "B6F33CE5-4712-5841-C308-B4217CDAFD68"
```

Example output:

```text
Scanning for device 'Aranet4'...
Connecting to Aranet4 228EB...
---------------------------------------
Connected: Aranet4 228EB | vv1.4.19
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

## Technical Details

### No Pairing Required

Unlike many Bluetooth devices, **Aranet4 sensors do not require pairing** for basic sensor readings. The tool reads from the "detailed" BLE characteristic (F0CD3001) which provides all sensor data without authentication.

### Characteristics Used

- **F0CD3001** (Detailed Current Readings) - Primary, no pairing required ✓
- **F0CD1503** (Basic Current Readings) - Requires pairing/authentication
- **F0CD1504** (AR2 Current Readings) - For Aranet2 devices

The tool automatically selects the best available characteristic based on device type and availability.

## Troubleshooting

### Bluetooth Permission Denied

If you see "Bluetooth access is not authorized", grant Bluetooth permissions:

1. Go to **System Settings → Privacy & Security → Bluetooth**
2. Enable Bluetooth access for Terminal or your shell application

### Device Not Found
4. Click **Connect**
5. Enter the PIN code shown on the device display
6. Click **Pair** or **Connect**
7. Run the aranetctl command again

**Note**: You only need to pair once. After pairing, the device will be remembered and future connections will work automatically.

**Alternative**: You can also pair the device using the official Aranet Home mobile app first, then use aranetctl.

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
3. Try increasing the scan timeout: `swift run aranetctl scan --timeout 15`
4. Check if the device is already connected to another application

### Device Not Found Error

If you get "Error: Device not found":

1. Run `swift run aranetctl scan` first to see available devices
2. Use the exact device name or UUID from the scan results
3. Device names are case-insensitive and support partial matching

## Supported Devices

- **Aranet4** - CO2, temperature, humidity, pressure
- **Aranet2** - Temperature, humidity (partial support)
- **Aranet Radiation** - Radiation measurements (partial support)
- **Aranet Radon Plus** - Radon concentration (partial support)

## Development

### Project Structure

```
Sources/aranetctl/
├── aranetctl.swift      # CLI interface
├── AranetClient.swift   # CoreBluetooth client
└── AranetTypes.swift    # Data models and types
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
