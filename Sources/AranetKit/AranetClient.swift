//
// AranetClient.swift
// AranetKit
//
// Swift reimplementation of the Python aranet4 library
// Based on https://github.com/Anrijs/Aranet4-Python
//
// Copyright (c) 2022 Anrijs Jargans (original Python implementation)
// Copyright (c) 2025 Heiko Panjas (Swift reimplementation)
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth
import Foundation

// MARK: - Bluetooth UUIDs

/// Bluetooth Low Energy service and characteristic UUIDs used by Aranet devices.
///
/// This structure contains all the standard and vendor-specific UUIDs required for
/// communicating with Aranet sensors via Bluetooth LE. The UUIDs are organized by
/// service type (GAP, DIS, SAF Tehnika) and their respective characteristics.
public struct AranetUUID {
    // MARK: GAP Service

    /// Generic Access Profile (GAP) service UUID.
    public static let serviceGAP = CBUUID(string: "1800")

    /// Device name characteristic (GAP service).
    public static let characteristicDeviceName = CBUUID(string: "2A00")

    // MARK: Device Information Service

    /// Device Information Service (DIS) UUID.
    public static let serviceDIS = CBUUID(string: "180A")

    /// Software/firmware revision string characteristic.
    public static let characteristicSoftwareRevision = CBUUID(string: "2A26")

    /// Serial number string characteristic.
    public static let characteristicSerialNumber = CBUUID(string: "2A25")

    // MARK: SAF Tehnika Service (Aranet)

    /// Primary SAF Tehnika service UUID (Aranet-specific).
    public static let serviceSAFTehnika = CBUUID(string: "FCE0")

    /// Legacy SAF Tehnika service UUID (older firmware versions).
    public static let serviceSAFTehnikaOld = CBUUID(string: "F0CD1400-95DA-4F4B-9AC8-AA55D312AF0C")

    // MARK: SAF Tehnika Characteristics

    /// Basic current readings characteristic (requires pairing/authentication).
    public static let characteristicCurrentReadings = CBUUID(string: "F0CD1503-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Detailed current readings characteristic (no pairing required, preferred).
    public static let characteristicCurrentReadingsDetailed = CBUUID(string: "F0CD3001-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Aranet2 current readings characteristic.
    public static let characteristicCurrentReadingsAR2 = CBUUID(string: "F0CD1504-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Aranet2/Radiation detailed current readings characteristic (no pairing required).
    public static let characteristicCurrentReadingsAR2Detailed = CBUUID(string: "F0CD3003-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Measurement interval characteristic (time between sensor updates).
    public static let characteristicInterval = CBUUID(string: "F0CD2002-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Seconds since last update characteristic (sensor data age).
    public static let characteristicSecondsSinceUpdate = CBUUID(string: "F0CD2004-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Total number of stored readings characteristic (history size).
    public static let characteristicTotalReadings = CBUUID(string: "F0CD2001-95DA-4F4B-9AC8-AA55D312AF0C")
}

// MARK: - Aranet Error

/// Errors that can occur during Aranet device communication.
///
/// These errors represent various failure modes when scanning for, connecting to,
/// or reading data from Aranet Bluetooth devices. Each error includes a descriptive
/// message to help diagnose and resolve issues.
public enum AranetError: Error {
    /// Bluetooth is not available or not ready for use.
    case bluetoothUnavailable

    /// Bluetooth access has not been authorized by the user.
    case bluetoothUnauthorized

    /// Bluetooth Low Energy is not supported on this device.
    case bluetoothUnsupported

    /// The requested Aranet device could not be found during scanning.
    case deviceNotFound

    /// Failed to establish a connection to the device.
    case connectionFailed

    /// Failed to read data from a Bluetooth characteristic.
    case readFailed

    /// Received data that could not be parsed or is in an unexpected format.
    case invalidData

    /// An operation exceeded its allowed time limit.
    case timeout

    /// The device requires Bluetooth pairing before accessing encrypted characteristics.
    case pairingRequired

    /// Human-readable description of the error with actionable guidance.
    public var description: String {
        switch self {
            case .bluetoothUnavailable:
                return "Bluetooth is unavailable or not ready"
            case .bluetoothUnauthorized:
                return "Bluetooth access is not authorized. Please grant Bluetooth permissions in System Settings."
            case .bluetoothUnsupported:
                return "Bluetooth is not supported on this device"
            case .deviceNotFound:
                return "Device not found"
            case .connectionFailed:
                return "Failed to connect to device"
            case .readFailed:
                return "Failed to read characteristic"
            case .invalidData:
                return "Invalid data received"
            case .timeout:
                return "Operation timed out"
            case .pairingRequired:
                return """
                    Device pairing required. The device will display a PIN code.

                    When you run this command, macOS should show a pairing dialog.
                    Enter the PIN code displayed on your Aranet device screen.

                    If no dialog appears:
                    1. Make sure the device is showing the PIN (it may timeout)
                    2. Try running the command again
                    3. The PIN is usually a 6-digit number like 122867

                    Note: The device won't appear in System Settings Bluetooth list.
                    This is normal for BLE devices - pairing happens through the app.
                    """
        }
    }
}

// MARK: - Aranet Client

/// Bluetooth Low Energy client for communicating with Aranet sensor devices.
///
/// `AranetClient` provides a high-level async/await API for discovering, connecting to,
/// and reading data from Aranet Bluetooth sensors (Aranet4, Aranet2, Aranet Radiation,
/// and Aranet Radon Plus). The client handles CoreBluetooth complexity internally and
/// presents a clean Swift concurrency interface.
///
/// The client runs on the main actor to satisfy CoreBluetooth's threading requirements.
/// All public methods are safe to call from any context and will automatically dispatch
/// to the main actor as needed.
///
/// Example usage:
/// ```swift
/// let client = AranetClient()
/// client.verbose = true  // Enable debug logging
///
/// // Scan for devices
/// let devices = try await client.scan(timeout: 5.0)
///
/// // Read current sensor values
/// if let device = devices.first {
///     let reading = try await client.readCurrentReadings(from: device)
///     print("CO2: \\(reading.co2 ?? 0) ppm")
/// }
/// ```
///
/// - Note: This class uses `@unchecked Sendable` because CoreBluetooth types are not
///   Sendable, but the implementation ensures thread-safe access through main actor isolation.
public class AranetClient: NSObject, @unchecked Sendable {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var continuation: CheckedContinuation<AranetReading, Error>?
    private var scanContinuation: CheckedContinuation<[CBPeripheral], Error>?
    private var bluetoothReadyContinuation: CheckedContinuation<Void, Error>?
    private var discoveredPeripherals: [CBPeripheral] = []

    private var deviceName: String = ""
    private var deviceVersion: String = ""
    private var readingData: Data?
    private var readingCharacteristicUUID: CBUUID?
    private var pendingReads: Set<CBUUID> = []
    private var servicesDiscovered = 0
    private var expectedServices = 0
    private var encryptionErrors = 0

    // Track which reading characteristics are available
    private var availableReadingChars: Set<CBUUID> = []

    /// Enables verbose debug logging to console.
    ///
    /// When set to `true`, the client will print detailed information about Bluetooth
    /// operations including scanning, connection status, service discovery, and data reads.
    /// Useful for troubleshooting connection issues or understanding device behavior.
    ///
    /// Default is `false`.
    public var verbose: Bool = false

    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public Methods

    private func waitForBluetoothReady() async throws {
        if verbose == true {
            print("[DEBUG] Checking Bluetooth state: \(centralManager.state.rawValue)")
        }

        if centralManager.state == .poweredOn {
            if verbose == true {
                print("[DEBUG] Bluetooth already powered on")
            }
            return
        }

        if centralManager.state != .unknown && centralManager.state != .resetting {
            if verbose == true {
                print("[DEBUG] Bluetooth state invalid: \(centralManager.state.rawValue)")
            }
            throw AranetError.bluetoothUnavailable
        }

        if verbose == true {
            print("[DEBUG] Waiting for Bluetooth to power on...")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.bluetoothReadyContinuation = continuation

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self.bluetoothReadyContinuation != nil {
                    if self.verbose == true {
                        print("[DEBUG] Bluetooth ready timeout")
                    }
                    self.bluetoothReadyContinuation?.resume(throwing: AranetError.bluetoothUnavailable)
                    self.bluetoothReadyContinuation = nil
                }
            }
        }
    }

    /// Scans for nearby Aranet Bluetooth devices.
    ///
    /// Performs a Bluetooth Low Energy scan looking for Aranet devices advertising their
    /// service UUIDs. The scan automatically stops after the specified timeout period.
    ///
    /// - Parameter timeout: Maximum time to scan in seconds. Default is 5.0 seconds.
    ///
    /// - Returns: Array of discovered `CBPeripheral` objects representing Aranet devices.
    ///   The array may be empty if no devices are found within the timeout period.
    ///
    /// - Throws: `AranetError` if Bluetooth is unavailable or unauthorized.
    ///
    /// - Note: Devices must be powered on and within Bluetooth range to be discovered.
    ///   The scan looks for both current and legacy Aranet service UUIDs.
    ///
    /// Example:
    /// ```swift
    /// let client = AranetClient()
    /// let devices = try await client.scan(timeout: 10.0)
    /// for device in devices {
    ///     print("Found: \\(device.name ?? "Unknown")")
    /// }
    /// ```
    public func scan(timeout: TimeInterval = 5.0) async throws -> [CBPeripheral] {
        try await waitForBluetoothReady()

        discoveredPeripherals.removeAll()

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else { return }

            self.scanContinuation = continuation

            centralManager.scanForPeripherals(
                withServices: [AranetUUID.serviceSAFTehnika, AranetUUID.serviceSAFTehnikaOld],
                options: nil
            )

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.centralManager.stopScan()
                let devices = self.discoveredPeripherals
                self.scanContinuation?.resume(returning: devices)
                self.scanContinuation = nil
            }
        }
    }

    /// Reads current sensor measurements from an Aranet device.
    ///
    /// Connects to the specified device (if not already connected), discovers its services
    /// and characteristics, then reads the current sensor data. The method automatically
    /// selects the best available reading characteristic based on device capabilities.
    ///
    /// For Aranet4 and similar devices, the detailed characteristic (F0CD3001) is preferred
    /// as it provides complete sensor data without requiring Bluetooth pairing.
    ///
    /// - Parameter peripheral: The `CBPeripheral` to read from, typically obtained from `scan()`.
    ///
    /// - Returns: An `AranetReading` struct containing all available sensor measurements,
    ///   device information, and metadata (battery, interval, age, etc.).
    ///
    /// - Throws: `AranetError` for various failure conditions:
    ///   - `.connectionFailed`: Could not connect to the device
    ///   - `.readFailed`: Could not read characteristic data
    ///   - `.invalidData`: Received data could not be parsed
    ///   - `.timeout`: Operation took too long (30 second timeout)
    ///   - `.pairingRequired`: Device requires pairing (rare, only for encrypted characteristics)
    ///
    /// - Note: The method includes a 30-second timeout. If the operation takes longer,
    ///   it will throw `.timeout`. The device connection is automatically closed after reading.
    ///
    /// Example:
    /// ```swift
    /// let client = AranetClient()
    /// let devices = try await client.scan()
    /// if let device = devices.first {
    ///     let reading = try await client.readCurrentReadings(from: device)
    ///     print("CO2: \\(reading.co2 ?? 0) ppm")
    ///     print("Temperature: \\(reading.temperature ?? 0) °C")
    ///     print("Battery: \\(reading.battery)%")
    /// }
    /// ```
    public func readCurrentReadings(from peripheral: CBPeripheral) async throws -> AranetReading {
        try await waitForBluetoothReady()

        // Reset state
        self.deviceName = ""
        self.deviceVersion = ""
        self.readingData = nil
        self.readingCharacteristicUUID = nil
        self.pendingReads = Set()
        self.servicesDiscovered = 0
        self.expectedServices = 0
        self.encryptionErrors = 0
        self.availableReadingChars = Set()

        self.peripheral = peripheral
        peripheral.delegate = self

        if verbose == true {
            print("[DEBUG] Starting read from device: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
            print("[DEBUG] Current connection state: \(peripheral.state.rawValue)")
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else { return }

            self.continuation = continuation

            if peripheral.state != .connected {
                if verbose == true {
                    print("[DEBUG] Connecting to peripheral...")
                }
                // Request pairing/bonding by specifying notification options
                let options: [String: Any] = [
                    CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
                ]
                centralManager.connect(peripheral, options: options)
            }
            else {
                if verbose == true {
                    print("[DEBUG] Already connected, discovering services...")
                }
                peripheral.discoverServices(nil)  // Discover ALL services
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Check for encryption errors after a short delay
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self.continuation != nil && self.encryptionErrors > 0 && self.readingData == nil {
                    if self.verbose == true {
                        print("[DEBUG] Detected encryption errors with no data - pairing required")
                    }
                    self.continuation?.resume(throwing: AranetError.pairingRequired)
                    self.continuation = nil
                    self.disconnect()
                    return
                }

                // Final timeout after 30 seconds
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                if self.continuation != nil {
                    if self.verbose == true {
                        print("[DEBUG] Operation timed out after 30 seconds")
                    }
                    self.continuation?.resume(throwing: AranetError.timeout)
                    self.continuation = nil
                    self.disconnect()
                }
            }
        }
    }

    /// Monitors an Aranet device with periodic automatic updates.
    ///
    /// This method performs an initial reading to determine the device's measurement interval,
    /// then schedules subsequent readings to occur 3 seconds after each expected sensor update.
    /// The timing is adaptive and uses the device's reported interval and age for accurate synchronization.
    ///
    /// - Parameters:
    ///   - peripheral: The connected peripheral to monitor
    ///
    /// - Returns: An async stream of sensor readings
    ///
    /// - Note: The stream will continue indefinitely until the task is cancelled or an error occurs.
    ///         Use a `for await` loop to consume the readings.
    ///
    /// Example:
    /// ```swift
    /// let stream = client.monitor(from: peripheral)
    /// for await result in stream {
    ///     switch result {
    ///     case .success(let reading):
    ///         print(reading.formatOutput())
    ///     case .failure(let error):
    ///         print("Error: \\(error)")
    ///     }
    /// }
    /// ```
    @MainActor
    public func monitor(from peripheral: CBPeripheral) -> AsyncStream<Result<AranetReading, Error>> {
        return AsyncStream { continuation in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                do {
                    // Initial reading
                    if self.verbose == true {
                        print("[DEBUG] Performing initial reading for monitoring setup...")
                    }

                    let initialReading = try await self.readCurrentReadings(from: peripheral)
                    continuation.yield(.success(initialReading))

                    // Check if we have interval information
                    guard let interval = initialReading.interval, let ago = initialReading.ago else {
                        continuation.yield(.failure(AranetError.invalidData))
                        continuation.finish()
                        return
                    }

                    // Calculate next update time - wait until next sensor update + 3s
                    let timeUntilNextUpdate = Int(interval) - Int(ago)
                    let firstReadDelay = timeUntilNextUpdate + 3

                    if self.verbose == true {
                        print("[DEBUG] Device interval: \(interval)s, ago: \(ago)s")
                        print("[DEBUG] Time until next sensor update: \(timeUntilNextUpdate)s")
                        print("[DEBUG] First reading in \(firstReadDelay) seconds...")
                    }

                    // Continue monitoring with recursive reads
                    await self.monitoringLoop(
                        from: peripheral,
                        interval: TimeInterval(interval),
                        initialDelay: TimeInterval(firstReadDelay),
                        continuation: continuation
                    )
                }
                catch {
                    if self.verbose == true {
                        print("[DEBUG] Initial monitoring read failed: \(error)")
                    }
                    continuation.yield(.failure(error))
                    continuation.finish()
                }
            }
        }
    }

    /// Internal monitoring loop that schedules periodic reads
    @MainActor
    private func monitoringLoop(
        from peripheral: CBPeripheral,
        interval: TimeInterval,
        initialDelay: TimeInterval,
        continuation: AsyncStream<Result<AranetReading, Error>>.Continuation
    ) async {
        var currentDelay = initialDelay
        let baseInterval = interval

        while Task.isCancelled == false {
            // Wait for the specified interval using Timer on main actor
            await withCheckedContinuation { (timerContinuation: CheckedContinuation<Void, Never>) in
                Timer.scheduledTimer(withTimeInterval: currentDelay, repeats: false) { _ in
                    timerContinuation.resume()
                }
            }

            // Check cancellation after timer
            if Task.isCancelled == true {
                continuation.finish()
                return
            }

            do {
                if self.verbose == true {
                    print("[DEBUG] Reading sensor data...")
                }

                let reading = try await self.readCurrentReadings(from: peripheral)
                continuation.yield(.success(reading))

                // Calculate next delay: wait for one full interval from now, plus 3 seconds
                // This ensures we read 3 seconds after the next sensor update
                if let ago = reading.ago {
                    // Time until next sensor update
                    let timeUntilNextUpdate = baseInterval - TimeInterval(ago)
                    currentDelay = timeUntilNextUpdate + 3.0

                    if self.verbose == true {
                        print("[DEBUG] Sensor age: \(ago)s, next update in \(Int(timeUntilNextUpdate))s")
                        print("[DEBUG] Next reading in \(Int(currentDelay)) seconds...")
                    }
                }
                else {
                    // Fallback: use base interval + 3 seconds
                    currentDelay = baseInterval + 3.0
                    if self.verbose == true {
                        print("[DEBUG] Age not available, using base interval + 3s")
                    }
                }
            }
            catch {
                if self.verbose == true {
                    print("[DEBUG] Monitoring read error: \(error)")
                }
                continuation.yield(.failure(error))
                continuation.finish()
                return
            }
        }

        continuation.finish()
    }

    private func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension AranetClient: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            bluetoothReadyContinuation?.resume()
            bluetoothReadyContinuation = nil
        }
        else if central.state == .unauthorized {
            let error = AranetError.bluetoothUnauthorized
            bluetoothReadyContinuation?.resume(throwing: error)
            bluetoothReadyContinuation = nil
            continuation?.resume(throwing: error)
            continuation = nil
        }
        else if central.state == .unsupported {
            let error = AranetError.bluetoothUnsupported
            bluetoothReadyContinuation?.resume(throwing: error)
            bluetoothReadyContinuation = nil
            continuation?.resume(throwing: error)
            continuation = nil
        }
        else if central.state != .unknown && central.state != .resetting {
            bluetoothReadyContinuation?.resume(throwing: AranetError.bluetoothUnavailable)
            bluetoothReadyContinuation = nil
            continuation?.resume(throwing: AranetError.bluetoothUnavailable)
            continuation = nil
        }
    }

    public func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if verbose == true {
            print("[DEBUG] Connected to peripheral: \(peripheral.name ?? "Unknown")")
            print("[DEBUG] Discovering services...")
        }
        peripheral.discoverServices(nil)  // Discover ALL services
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if verbose == true {
            print("[DEBUG] Failed to connect: \(error?.localizedDescription ?? "unknown error")")
        }
        continuation?.resume(throwing: error ?? AranetError.connectionFailed)
        continuation = nil
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if verbose == true {
            print("[DEBUG] Disconnected from peripheral: \(error?.localizedDescription ?? "clean disconnect")")
        }
        self.peripheral = nil
    }
}

// MARK: - CBPeripheralDelegate

extension AranetClient: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if verbose == true {
            print("[DEBUG] Discovered services: \(peripheral.services?.count ?? 0)")
        }

        guard error == nil, let services = peripheral.services else {
            if verbose == true {
                print("[DEBUG] Error discovering services: \(error?.localizedDescription ?? "unknown")")
            }
            continuation?.resume(throwing: error ?? AranetError.readFailed)
            continuation = nil
            return
        }

        expectedServices = services.count

        for service in services {
            if verbose == true {
                print("[DEBUG] Discovering characteristics for service: \(service.uuid)")
            }
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        servicesDiscovered += 1

        if verbose == true {
            print("[DEBUG] Discovered \(service.characteristics?.count ?? 0) characteristics for service: \(service.uuid)")
            print("[DEBUG] Services discovered: \(servicesDiscovered)/\(expectedServices)")
        }

        guard error == nil, let characteristics = service.characteristics else {
            if verbose == true {
                print("[DEBUG] Error discovering characteristics: \(error?.localizedDescription ?? "unknown")")
            }
            return
        }

        for characteristic in characteristics {
            if verbose == true {
                print("[DEBUG] Found characteristic: \(characteristic.uuid) (properties: \(characteristic.properties.rawValue))")
            }

            if characteristic.uuid == AranetUUID.characteristicDeviceName {
                if verbose == true {
                    print("[DEBUG] Reading device name...")
                }
                pendingReads.insert(characteristic.uuid)
                peripheral.readValue(for: characteristic)
            }
            else if characteristic.uuid == AranetUUID.characteristicSoftwareRevision {
                if verbose == true {
                    print("[DEBUG] Reading software revision...")
                }
                pendingReads.insert(characteristic.uuid)
                peripheral.readValue(for: characteristic)
            }
            else if characteristic.uuid == AranetUUID.characteristicCurrentReadingsDetailed {
                if verbose == true {
                    print("[DEBUG] Found detailed current readings characteristic")
                }
                availableReadingChars.insert(characteristic.uuid)
            }
            else if characteristic.uuid == AranetUUID.characteristicCurrentReadings {
                if verbose == true {
                    print("[DEBUG] Found basic current readings characteristic")
                }
                availableReadingChars.insert(characteristic.uuid)
            }
            else if characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2Detailed {
                if verbose == true {
                    print("[DEBUG] Found AR2 detailed current readings characteristic")
                }
                availableReadingChars.insert(characteristic.uuid)
            }
            else if characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2 {
                if verbose == true {
                    print("[DEBUG] Found AR2 current readings characteristic")
                }
                availableReadingChars.insert(characteristic.uuid)
            }
        }

        // Only check if we've discovered all services
        if servicesDiscovered == expectedServices {
            if verbose == true {
                print("[DEBUG] All services discovered. Available reading characteristics: \(availableReadingChars.count)")
            }

            // Now decide which characteristic to read based on priority
            var readingCharToRead: CBUUID? = nil

            // Priority: Detailed (Aranet4) > AR2 Detailed > AR2 Basic > Basic (Aranet4)
            if availableReadingChars.contains(AranetUUID.characteristicCurrentReadingsDetailed) {
                readingCharToRead = AranetUUID.characteristicCurrentReadingsDetailed
                if verbose == true {
                    print("[DEBUG] Will read detailed current readings (F0CD3001)")
                }
            }
            else if availableReadingChars.contains(AranetUUID.characteristicCurrentReadingsAR2Detailed) {
                readingCharToRead = AranetUUID.characteristicCurrentReadingsAR2Detailed
                if verbose == true {
                    print("[DEBUG] Will read AR2 detailed current readings (F0CD3003)")
                }
            }
            else if availableReadingChars.contains(AranetUUID.characteristicCurrentReadingsAR2) {
                readingCharToRead = AranetUUID.characteristicCurrentReadingsAR2
                if verbose == true {
                    print("[DEBUG] Will read AR2 current readings (F0CD1504)")
                }
            }
            else if availableReadingChars.contains(AranetUUID.characteristicCurrentReadings) {
                readingCharToRead = AranetUUID.characteristicCurrentReadings
                if verbose == true {
                    print("[DEBUG] Will read basic current readings (F0CD1503)")
                }
            }

            // Now initiate the reads
            if let readingChar = readingCharToRead {
                readingCharacteristicUUID = readingChar
                // Find the characteristic and read it
                for service in peripheral.services ?? [] {
                    if let characteristics = service.characteristics {
                        for char in characteristics {
                            if char.uuid == readingChar {
                                pendingReads.insert(char.uuid)
                                peripheral.readValue(for: char)
                                if verbose == true {
                                    print("[DEBUG] Reading from \(char.uuid)")
                                }
                            }
                        }
                    }
                }
            }

            if verbose == true {
                print("[DEBUG] Pending reads: \(pendingReads.count)")
            }

            // If we have reading data but no more mandatory reads, complete
            if readingData != nil && pendingReads.isEmpty {
                if verbose == true {
                    print("[DEBUG] Have reading data and no pending reads, completing...")
                }
                completeReading()
            }
            else if pendingReads.isEmpty {
                if verbose == true {
                    print("[DEBUG] All services discovered but no reading characteristics found!")
                }
                continuation?.resume(throwing: AranetError.readFailed)
                continuation = nil
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Check for authentication/encryption errors
        if let error = error {
            let nsError = error as NSError

            // Check if this is an authentication error (code 15 = insufficient encryption/authentication)
            if nsError.domain == "CBATTErrorDomain" && nsError.code == 15 {
                if verbose == true {
                    print(
                        "[DEBUG] Authentication error on characteristic \(characteristic.uuid) - this is expected for F0CD1503, we use F0CD3001 instead"
                    )
                }
                pendingReads.remove(characteristic.uuid)

                // Don't treat this as fatal if we have data from another characteristic
                // The detailed characteristic (F0CD3001) doesn't require pairing
                return
            }

            // Other errors
            if verbose == true {
                print("[DEBUG] Error reading characteristic \(characteristic.uuid): \(error.localizedDescription)")
            }
            pendingReads.remove(characteristic.uuid)
            return
        }

        guard let data = characteristic.value else {
            if verbose == true {
                print("[DEBUG] ⚠️ No data returned for characteristic \(characteristic.uuid) - this may indicate pairing required")
            }
            pendingReads.remove(characteristic.uuid)

            // If this is one of the reading characteristics and we got no data, treat as encryption issue
            if characteristic.uuid == AranetUUID.characteristicCurrentReadingsDetailed
                || characteristic.uuid == AranetUUID.characteristicCurrentReadings
                || characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2
                || characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2Detailed
            {
                encryptionErrors += 1
                if verbose == true {
                    print("[DEBUG] ⚠️ Reading characteristic returned no data - likely needs pairing (count: \(encryptionErrors))")
                }
            }
            return
        }

        if verbose == true {
            print("[DEBUG] Read characteristic \(characteristic.uuid): \(data.count) bytes")
        }

        pendingReads.remove(characteristic.uuid)

        if characteristic.uuid == AranetUUID.characteristicDeviceName {
            deviceName = String(data: data, encoding: .utf8) ?? ""
            if verbose == true {
                print("[DEBUG] Device name: \(deviceName)")
            }
        }
        else if characteristic.uuid == AranetUUID.characteristicSoftwareRevision {
            deviceVersion = String(data: data, encoding: .utf8) ?? ""
            if verbose == true {
                print("[DEBUG] Software version: \(deviceVersion)")
            }
        }
        else if characteristic.uuid == AranetUUID.characteristicCurrentReadingsDetailed
            || characteristic.uuid == AranetUUID.characteristicCurrentReadings
            || characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2
            || characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2Detailed
        {
            readingData = data
            if verbose == true {
                print("[DEBUG] Got reading data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
        }

        if verbose == true {
            print("[DEBUG] Pending reads remaining: \(pendingReads.count)")
        }

        if pendingReads.isEmpty && readingData != nil {
            if verbose == true {
                print("[DEBUG] All reads complete, parsing data...")
            }
            completeReading()
        }
    }

    // Add delegate methods for pairing/authentication monitoring
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        if verbose == true {
            print("[DEBUG] Peripheral services were modified")
        }
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        if verbose == true {
            print("[DEBUG] Peripheral ready to send write without response")
        }
    }

    private func completeReading() {
        guard let data = readingData else {
            continuation?.resume(throwing: AranetError.invalidData)
            continuation = nil
            return
        }

        do {
            // Use peripheral name as fallback if deviceName is empty
            let name = deviceName.isEmpty ? (peripheral?.name ?? "Unknown") : deviceName
            let reading = try parseReading(data: data, name: name, version: deviceVersion, characteristicUUID: readingCharacteristicUUID)
            continuation?.resume(returning: reading)
            continuation = nil
            disconnect()
        }
        catch {
            continuation?.resume(throwing: error)
            continuation = nil
            disconnect()
        }
    }

    private func parseReading(data: Data, name: String, version: String, characteristicUUID: CBUUID?) throws -> AranetReading {
        var offset = 0

        func readUInt16LE() -> UInt16 {
            let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
            offset += 2
            return UInt16(littleEndian: value)
        }

        func readUInt32LE() -> UInt32 {
            let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
            offset += 4
            return UInt32(littleEndian: value)
        }

        func readUInt64LE() -> UInt64 {
            let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self) }
            offset += 8
            return UInt64(littleEndian: value)
        }

        func readUInt8() -> UInt8 {
            let value = data[offset]
            offset += 1
            return value
        }

        // Check if this is F0CD1504 or F0CD3003 (AR2 characteristics) which support multiple device types
        if characteristicUUID == AranetUUID.characteristicCurrentReadingsAR2
            || characteristicUUID == AranetUUID.characteristicCurrentReadingsAR2Detailed
        {
            guard data.count >= 1 else {
                throw AranetError.invalidData
            }

            let deviceTypeByte = readUInt8()
            offset = 0 // Reset offset to parse from beginning

            // Aranet Radiation (Nucleo) - first byte = 4
            if deviceTypeByte == 4 {
                // F0CD1504 format: <HHHBIQQB (28 bytes) - includes interval/ago in first bytes
                // F0CD3003 format: 48 bytes - interval/ago may be at different positions
                if data.count == 28 {
                    // F0CD1504 format (28 bytes)
                    guard data.count >= 28 else {
                        throw AranetError.invalidData
                    }

                    // Format: <HHHBIQQB (28 bytes)
                    // Skip first byte (device type)
                    offset = 1
                    let interval = readUInt16LE()
                    let ago = readUInt16LE()
                    let battery = readUInt8()
                    let radiationRateRaw = readUInt32LE()
                    let radiationTotal = readUInt64LE()
                    let radiationDuration = readUInt64LE()

                    // radiation_rate is stored as nSv/h * 10, divide by 10 to get nSv/h
                    let radiationRate = Double(radiationRateRaw) / 10.0

                    return AranetReading(
                        deviceType: .aranetRadiation,
                        name: name,
                        version: version,
                        temperature: nil,
                        humidity: nil,
                        co2: nil,
                        pressure: nil,
                        radiationRate: radiationRate,
                        radiationTotal: Double(radiationTotal),
                        radiationDuration: radiationDuration,
                        radonConcentration: nil,
                        battery: battery,
                        status: nil,
                        interval: interval,
                        ago: ago
                    )
                }
                else if data.count >= 48 {
                    // F0CD3003 format (48 bytes) - uses same <HHHBIQQB format as F0CD1504 for first 28 bytes
                    // Python format <HHHBIQQB unpacks bytes 0-27:
                    //   value[0] = bytes 0-1 (H) - includes device type byte (0x0004)
                    //   value[1] = bytes 2-3 (H) - interval
                    //   value[2] = bytes 4-5 (H) - ago
                    //   value[3] = byte 6 (B) - battery
                    //   value[4] = bytes 7-10 (I) - rate
                    //   value[5] = bytes 11-18 (Q) - total
                    //   value[6] = bytes 19-26 (Q) - duration
                    //   value[7] = byte 27 (B) - unknown
                    // Skip bytes 0-1 (device type + first H from Python struct)
                    offset = 2
                    let interval = readUInt16LE()    // Read bytes 2-3 (value[1] from Python)
                    let ago = readUInt16LE()         // Read bytes 4-5 (value[2] from Python)
                    let battery = readUInt8()        // Read byte 6 (value[3] from Python)

                    if verbose == true {
                        print("[DEBUG] F0CD3003 parsing: interval=\(interval), ago=\(ago), battery=\(battery)")
                    }
                    let radiationRateRaw = readUInt32LE()  // Bytes 7-10
                    let radiationTotal = readUInt64LE()    // Bytes 11-18
                    let radiationDuration = readUInt64LE() // Bytes 19-26
                    // Remaining 20 bytes are extended data, ignore for now

                    // For F0CD3003, rate is stored as nSv/h (NOT multiplied by 10 like F0CD1504)
                    // Store in nSv/h (formatOutput will convert to µSv/h for display)
                    let radiationRate = Double(radiationRateRaw)

                    return AranetReading(
                        deviceType: .aranetRadiation,
                        name: name,
                        version: version,
                        temperature: nil,
                        humidity: nil,
                        co2: nil,
                        pressure: nil,
                        radiationRate: radiationRate,
                        radiationTotal: Double(radiationTotal),
                        radiationDuration: radiationDuration,
                        radonConcentration: nil,
                        battery: battery,
                        status: nil,
                        interval: interval,
                        ago: ago
                    )
                }
                else {
                    throw AranetError.invalidData
                }
            }
            // Aranet2 - first byte = 2
            else if deviceTypeByte == 2 {
                guard data.count >= 8 else {
                    throw AranetError.invalidData
                }

                // Format: <HHHBHHB
                // Skip first byte (device type)
                offset = 1
                let interval = readUInt16LE()
                let ago = readUInt16LE()
                let battery = readUInt8()
                let tempRaw = readUInt16LE()
                let humidity = readUInt8()
                let statusRaw = readUInt8()

                let temperature = Double(tempRaw) / 20.0

                return AranetReading(
                    deviceType: .aranet2,
                    name: name,
                    version: version,
                    temperature: temperature,
                    humidity: humidity,
                    co2: nil,
                    pressure: nil,
                    radiationRate: nil,
                    radiationTotal: nil,
                    radiationDuration: nil,
                    radonConcentration: nil,
                    battery: battery,
                    status: nil,
                    interval: interval,
                    ago: ago
                )
            }
            // Aranet Radon - first byte = 3 (not fully implemented yet)
            else if deviceTypeByte == 3 {
                throw AranetError.invalidData // Radon parsing not yet implemented
            }
            else {
                throw AranetError.invalidData
            }
        }
        // Aranet4 format (F0CD3001 detailed or F0CD1503 basic)
        else {
            guard data.count >= 7 else {
                throw AranetError.invalidData
            }

            offset = 0
            let co2 = readUInt16LE()
            let tempRaw = readUInt16LE()
            let pressureRaw = readUInt16LE()
            let humidity = readUInt8()
            let battery = readUInt8()
            let statusRaw = readUInt8()

            let temperature = Double(tempRaw) / 20.0
            let pressure = Double(pressureRaw) / 10.0
            let status = AranetStatusColor(rawValue: statusRaw)

            var interval: UInt16?
            var ago: UInt16?

            if data.count >= 11 {
                interval = readUInt16LE()
                ago = readUInt16LE()
            }

            return AranetReading(
                deviceType: .aranet4,
                name: name,
                version: version,
                temperature: temperature,
                humidity: humidity,
                co2: co2,
                pressure: pressure,
                battery: battery,
                status: status,
                interval: interval,
                ago: ago
            )
        }
    }
}
