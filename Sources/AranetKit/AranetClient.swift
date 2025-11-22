@preconcurrency import CoreBluetooth
import Foundation

// MARK: - Bluetooth UUIDs

public struct AranetUUID {
    // GAP Service
    public static let serviceGAP = CBUUID(string: "1800")
    public static let characteristicDeviceName = CBUUID(string: "2A00")

    // Device Information Service
    public static let serviceDIS = CBUUID(string: "180A")
    public static let characteristicSoftwareRevision = CBUUID(string: "2A26")
    public static let characteristicSerialNumber = CBUUID(string: "2A25")

    // SAF Tehnika Service (Aranet)
    public static let serviceSAFTehnika = CBUUID(string: "FCE0")
    public static let serviceSAFTehnikaOld = CBUUID(string: "F0CD1400-95DA-4F4B-9AC8-AA55D312AF0C")

    // SAF Tehnika Characteristics
    public static let characteristicCurrentReadings = CBUUID(string: "F0CD1503-95DA-4F4B-9AC8-AA55D312AF0C")
    public static let characteristicCurrentReadingsDetailed = CBUUID(string: "F0CD3001-95DA-4F4B-9AC8-AA55D312AF0C")
    public static let characteristicCurrentReadingsAR2 = CBUUID(string: "F0CD1504-95DA-4F4B-9AC8-AA55D312AF0C")
    public static let characteristicInterval = CBUUID(string: "F0CD2002-95DA-4F4B-9AC8-AA55D312AF0C")
    public static let characteristicSecondsSinceUpdate = CBUUID(string: "F0CD2004-95DA-4F4B-9AC8-AA55D312AF0C")
    public static let characteristicTotalReadings = CBUUID(string: "F0CD2001-95DA-4F4B-9AC8-AA55D312AF0C")
}

// MARK: - Aranet Error

public enum AranetError: Error {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case deviceNotFound
    case connectionFailed
    case readFailed
    case invalidData
    case timeout
    case pairingRequired

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
    private var pendingReads: Set<CBUUID> = []
    private var servicesDiscovered = 0
    private var expectedServices = 0
    private var encryptionErrors = 0

    // Track which reading characteristics are available
    private var availableReadingChars: Set<CBUUID> = []

    public var verbose: Bool = false

    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public Methods

    private func waitForBluetoothReady() async throws {
        if verbose {
            print("[DEBUG] Checking Bluetooth state: \(centralManager.state.rawValue)")
        }

        if centralManager.state == .poweredOn {
            if verbose {
                print("[DEBUG] Bluetooth already powered on")
            }
            return
        }

        if centralManager.state != .unknown && centralManager.state != .resetting {
            if verbose {
                print("[DEBUG] Bluetooth state invalid: \(centralManager.state.rawValue)")
            }
            throw AranetError.bluetoothUnavailable
        }

        if verbose {
            print("[DEBUG] Waiting for Bluetooth to power on...")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.bluetoothReadyContinuation = continuation

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self.bluetoothReadyContinuation != nil {
                    if self.verbose {
                        print("[DEBUG] Bluetooth ready timeout")
                    }
                    self.bluetoothReadyContinuation?.resume(throwing: AranetError.bluetoothUnavailable)
                    self.bluetoothReadyContinuation = nil
                }
            }
        }
    }

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

    public func readCurrentReadings(from peripheral: CBPeripheral) async throws -> AranetReading {
        try await waitForBluetoothReady()

        // Reset state
        self.deviceName = ""
        self.deviceVersion = ""
        self.readingData = nil
        self.pendingReads = Set()
        self.servicesDiscovered = 0
        self.expectedServices = 0
        self.encryptionErrors = 0
        self.availableReadingChars = Set()

        self.peripheral = peripheral
        peripheral.delegate = self

        if verbose {
            print("[DEBUG] Starting read from device: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
            print("[DEBUG] Current connection state: \(peripheral.state.rawValue)")
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else { return }

            self.continuation = continuation

            if peripheral.state != .connected {
                if verbose {
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
                if verbose {
                    print("[DEBUG] Already connected, discovering services...")
                }
                peripheral.discoverServices(nil)  // Discover ALL services
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Check for encryption errors after a short delay
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self.continuation != nil && self.encryptionErrors > 0 && self.readingData == nil {
                    if self.verbose {
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
                    if self.verbose {
                        print("[DEBUG] Operation timed out after 30 seconds")
                    }
                    self.continuation?.resume(throwing: AranetError.timeout)
                    self.continuation = nil
                    self.disconnect()
                }
            }
        }
    }

    public func disconnect() {
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
        if verbose {
            print("[DEBUG] Connected to peripheral: \(peripheral.name ?? "Unknown")")
            print("[DEBUG] Discovering services...")
        }
        peripheral.discoverServices(nil)  // Discover ALL services
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if verbose {
            print("[DEBUG] Failed to connect: \(error?.localizedDescription ?? "unknown error")")
        }
        continuation?.resume(throwing: error ?? AranetError.connectionFailed)
        continuation = nil
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if verbose {
            print("[DEBUG] Disconnected from peripheral: \(error?.localizedDescription ?? "clean disconnect")")
        }
        self.peripheral = nil
    }
}

// MARK: - CBPeripheralDelegate

extension AranetClient: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if verbose {
            print("[DEBUG] Discovered services: \(peripheral.services?.count ?? 0)")
        }

        guard error == nil, let services = peripheral.services else {
            if verbose {
                print("[DEBUG] Error discovering services: \(error?.localizedDescription ?? "unknown")")
            }
            continuation?.resume(throwing: error ?? AranetError.readFailed)
            continuation = nil
            return
        }

        expectedServices = services.count

        for service in services {
            if verbose {
                print("[DEBUG] Discovering characteristics for service: \(service.uuid)")
            }
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        servicesDiscovered += 1

        if verbose {
            print("[DEBUG] Discovered \(service.characteristics?.count ?? 0) characteristics for service: \(service.uuid)")
            print("[DEBUG] Services discovered: \(servicesDiscovered)/\(expectedServices)")
        }

        guard error == nil, let characteristics = service.characteristics else {
            if verbose {
                print("[DEBUG] Error discovering characteristics: \(error?.localizedDescription ?? "unknown")")
            }
            return
        }

        for characteristic in characteristics {
            if verbose {
                print("[DEBUG] Found characteristic: \(characteristic.uuid) (properties: \(characteristic.properties.rawValue))")
            }

            if characteristic.uuid == AranetUUID.characteristicDeviceName {
                if verbose {
                    print("[DEBUG] Reading device name...")
                }
                pendingReads.insert(characteristic.uuid)
                peripheral.readValue(for: characteristic)
            }
            else if characteristic.uuid == AranetUUID.characteristicSoftwareRevision {
                if verbose {
                    print("[DEBUG] Reading software revision...")
                }
                pendingReads.insert(characteristic.uuid)
                peripheral.readValue(for: characteristic)
            }
            else if characteristic.uuid == AranetUUID.characteristicCurrentReadingsDetailed {
                if verbose {
                    print("[DEBUG] Found detailed current readings characteristic")
                }
                availableReadingChars.insert(characteristic.uuid)
            }
            else if characteristic.uuid == AranetUUID.characteristicCurrentReadings {
                if verbose {
                    print("[DEBUG] Found basic current readings characteristic")
                }
                availableReadingChars.insert(characteristic.uuid)
            }
            else if characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2 {
                if verbose {
                    print("[DEBUG] Found AR2 current readings characteristic")
                }
                availableReadingChars.insert(characteristic.uuid)
            }
        }

        // Only check if we've discovered all services
        if servicesDiscovered == expectedServices {
            if verbose {
                print("[DEBUG] All services discovered. Available reading characteristics: \(availableReadingChars.count)")
            }

            // Now decide which characteristic to read based on priority
            var readingCharToRead: CBUUID? = nil

            // Priority: Detailed > AR2 > Basic
            if availableReadingChars.contains(AranetUUID.characteristicCurrentReadingsDetailed) {
                readingCharToRead = AranetUUID.characteristicCurrentReadingsDetailed
                if verbose {
                    print("[DEBUG] Will read detailed current readings (F0CD3001)")
                }
            }
            else if availableReadingChars.contains(AranetUUID.characteristicCurrentReadingsAR2) {
                readingCharToRead = AranetUUID.characteristicCurrentReadingsAR2
                if verbose {
                    print("[DEBUG] Will read AR2 current readings (F0CD1504)")
                }
            }
            else if availableReadingChars.contains(AranetUUID.characteristicCurrentReadings) {
                readingCharToRead = AranetUUID.characteristicCurrentReadings
                if verbose {
                    print("[DEBUG] Will read basic current readings (F0CD1503)")
                }
            }

            // Now initiate the reads
            if let readingChar = readingCharToRead {
                // Find the characteristic and read it
                for service in peripheral.services ?? [] {
                    if let characteristics = service.characteristics {
                        for char in characteristics {
                            if char.uuid == readingChar {
                                pendingReads.insert(char.uuid)
                                peripheral.readValue(for: char)
                                if verbose {
                                    print("[DEBUG] Reading from \(char.uuid)")
                                }
                            }
                        }
                    }
                }
            }

            if verbose {
                print("[DEBUG] Pending reads: \(pendingReads.count)")
            }

            // If we have reading data but no more mandatory reads, complete
            if readingData != nil && pendingReads.isEmpty {
                if verbose {
                    print("[DEBUG] Have reading data and no pending reads, completing...")
                }
                completeReading()
            }
            else if pendingReads.isEmpty {
                if verbose {
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
                if verbose {
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
            if verbose {
                print("[DEBUG] Error reading characteristic \(characteristic.uuid): \(error.localizedDescription)")
            }
            pendingReads.remove(characteristic.uuid)
            return
        }

        guard let data = characteristic.value else {
            if verbose {
                print("[DEBUG] ⚠️ No data returned for characteristic \(characteristic.uuid) - this may indicate pairing required")
            }
            pendingReads.remove(characteristic.uuid)

            // If this is one of the reading characteristics and we got no data, treat as encryption issue
            if characteristic.uuid == AranetUUID.characteristicCurrentReadingsDetailed
                || characteristic.uuid == AranetUUID.characteristicCurrentReadings
                || characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2
            {
                encryptionErrors += 1
                if verbose {
                    print("[DEBUG] ⚠️ Reading characteristic returned no data - likely needs pairing (count: \(encryptionErrors))")
                }
            }
            return
        }

        if verbose {
            print("[DEBUG] Read characteristic \(characteristic.uuid): \(data.count) bytes")
        }

        pendingReads.remove(characteristic.uuid)

        if characteristic.uuid == AranetUUID.characteristicDeviceName {
            deviceName = String(data: data, encoding: .utf8) ?? ""
            if verbose {
                print("[DEBUG] Device name: \(deviceName)")
            }
        }
        else if characteristic.uuid == AranetUUID.characteristicSoftwareRevision {
            deviceVersion = String(data: data, encoding: .utf8) ?? ""
            if verbose {
                print("[DEBUG] Software version: \(deviceVersion)")
            }
        }
        else if characteristic.uuid == AranetUUID.characteristicCurrentReadingsDetailed
            || characteristic.uuid == AranetUUID.characteristicCurrentReadings
            || characteristic.uuid == AranetUUID.characteristicCurrentReadingsAR2
        {
            readingData = data
            if verbose {
                print("[DEBUG] Got reading data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
        }

        if verbose {
            print("[DEBUG] Pending reads remaining: \(pendingReads.count)")
        }

        if pendingReads.isEmpty && readingData != nil {
            if verbose {
                print("[DEBUG] All reads complete, parsing data...")
            }
            completeReading()
        }
    }

    // Add delegate methods for pairing/authentication monitoring
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        if verbose {
            print("[DEBUG] Peripheral services were modified")
        }
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        if verbose {
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
            let reading = try parseReading(data: data, name: name, version: deviceVersion)
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

    private func parseReading(data: Data, name: String, version: String) throws -> AranetReading {
        guard data.count >= 7 else {
            throw AranetError.invalidData
        }

        var offset = 0

        func readUInt16LE() -> UInt16 {
            let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
            offset += 2
            return UInt16(littleEndian: value)
        }

        func readUInt8() -> UInt8 {
            let value = data[offset]
            offset += 1
            return value
        }

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
