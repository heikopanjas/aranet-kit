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
  public static let characteristicCurrentReadings = CBUUID(
    string: "F0CD1503-95DA-4F4B-9AC8-AA55D312AF0C")

  /// Detailed current readings characteristic (no pairing required, preferred).
  public static let characteristicCurrentReadingsDetailed = CBUUID(
    string: "F0CD3001-95DA-4F4B-9AC8-AA55D312AF0C")

  /// Aranet2 current readings characteristic.
  public static let characteristicCurrentReadingsAR2 = CBUUID(
    string: "F0CD1504-95DA-4F4B-9AC8-AA55D312AF0C")

  /// Aranet2/Radiation detailed current readings characteristic (no pairing required).
  public static let characteristicCurrentReadingsAR2Detailed = CBUUID(
    string: "F0CD3003-95DA-4F4B-9AC8-AA55D312AF0C")

  /// Measurement interval characteristic (time between sensor updates).
  public static let characteristicInterval = CBUUID(string: "F0CD2002-95DA-4F4B-9AC8-AA55D312AF0C")

  /// Seconds since last update characteristic (sensor data age).
  public static let characteristicSecondsSinceUpdate = CBUUID(
    string: "F0CD2004-95DA-4F4B-9AC8-AA55D312AF0C")

  /// Total number of stored readings characteristic (history size).
  public static let characteristicTotalReadings = CBUUID(
    string: "F0CD2001-95DA-4F4B-9AC8-AA55D312AF0C")

  /// Priority-ordered list of reading characteristics to try.
  /// Detailed variants (no pairing required) are preferred over basic ones.
  public static let readingCharacteristicPriority: [CBUUID] = [
    characteristicCurrentReadingsDetailed,
    characteristicCurrentReadingsAR2Detailed,
    characteristicCurrentReadingsAR2,
    characteristicCurrentReadings,
  ]

  /// Set of all characteristic UUIDs that provide sensor reading data.
  public static let readingCharacteristics: Set<CBUUID> = Set(readingCharacteristicPriority)
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
      return
        "Bluetooth access is not authorized. Please grant Bluetooth permissions in System Settings."
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

// MARK: - Read Operation (per-peripheral state)

/// Encapsulates all mutable state for a single read operation against one peripheral.
/// Each concurrent read gets its own instance, preventing cross-device state corruption.
private class ReadOperation {
  let peripheral: CBPeripheral
  var continuation: CheckedContinuation<AranetReading, Error>?
  var deviceName: String = ""
  var deviceVersion: String = ""
  var readingData: Data?
  var readingCharacteristicUUID: CBUUID?
  var pendingReads: Set<CBUUID> = []
  var servicesDiscovered = 0
  var expectedServices = 0
  var encryptionErrors = 0
  var availableReadingChars: Set<CBUUID> = []

  init(peripheral: CBPeripheral) {
    self.peripheral = peripheral
  }
}

// MARK: - Aranet Client

/// Bluetooth Low Energy client for communicating with Aranet sensor devices.
///
/// `AranetClient` provides a high-level async/await API for discovering, connecting to,
/// and reading data from Aranet Bluetooth sensors (Aranet4, Aranet2, Aranet Radiation,
/// and Aranet Radon Plus). CoreBluetooth is fully encapsulated -- consumers only work
/// with ``AranetDevice`` and ``AranetReading`` types.
///
/// The client supports concurrent monitoring of multiple devices. Each read operation
/// maintains isolated state so simultaneous reads do not interfere with each other.
///
/// Example usage:
/// ```swift
/// let client = AranetClient()
/// let devices = try await client.scan(timeout: 5.0)
///
/// if let device = devices.first {
///     let reading = try await client.readCurrentReadings(from: device)
///     print("CO2: \(reading.co2 ?? 0) ppm")
/// }
/// ```
public class AranetClient: NSObject, @unchecked Sendable {
  // swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals
  private var centralManager: CBCentralManager!

  // Scan state
  private var scanContinuation: CheckedContinuation<[CBPeripheral], Error>?
  private var bluetoothReadyContinuation: CheckedContinuation<Void, Error>?
  private var discoveredPeripherals: [CBPeripheral] = []

  // Maps public AranetDevice.id -> CBPeripheral for internal use
  private var knownPeripherals: [UUID: CBPeripheral] = [:]

  // Per-peripheral read state keyed by peripheral.identifier
  private var activeOperations: [UUID: ReadOperation] = [:]

  /// Enables verbose debug logging to console.
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
  /// - Parameter timeout: Maximum time to scan in seconds. Default is 15.0 seconds.
  /// - Returns: Array of discovered ``AranetDevice`` values.
  /// - Throws: ``AranetError`` if Bluetooth is unavailable or unauthorized.
  @MainActor
  public func scan(timeout: TimeInterval = 15.0) async throws -> [AranetDevice] {
    try await waitForBluetoothReady()

    discoveredPeripherals.removeAll()

    if verbose == true {
      print("[DEBUG] Starting BLE scan for \(timeout) seconds...")
    }

    let peripherals: [CBPeripheral] = try await withCheckedThrowingContinuation {
      [weak self] continuation in
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

    for peripheral in peripherals {
      knownPeripherals[peripheral.identifier] = peripheral
    }

    return peripherals.map { AranetDevice(id: $0.identifier, name: $0.name ?? "Unknown") }
  }

  /// Reads current sensor measurements from an Aranet device.
  ///
  /// Connects to the specified device, discovers its services and characteristics,
  /// then reads the current sensor data. Supports concurrent reads from multiple devices.
  ///
  /// - Parameter device: The ``AranetDevice`` to read from, obtained from ``scan(timeout:)``.
  /// - Returns: An ``AranetReading`` containing all available sensor measurements.
  /// - Throws: ``AranetError`` for connection, read, or timeout failures.
  @MainActor
  public func readCurrentReadings(from device: AranetDevice) async throws -> AranetReading {
    try await waitForBluetoothReady()

    guard let peripheral = knownPeripherals[device.id] else {
      throw AranetError.deviceNotFound
    }

    let operation = ReadOperation(peripheral: peripheral)
    activeOperations[device.id] = operation
    peripheral.delegate = self

    if verbose == true {
      print(
        "[DEBUG] Starting read from device: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))"
      )
      print("[DEBUG] Current connection state: \(peripheral.state.rawValue)")
    }

    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let self = self else { return }

      operation.continuation = continuation

      if peripheral.state != .connected {
        if verbose == true {
          print("[DEBUG] Connecting to peripheral...")
        }
        let options: [String: Any] = [
          CBConnectPeripheralOptionNotifyOnConnectionKey: true,
          CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
        ]
        centralManager.connect(peripheral, options: options)
      } else {
        if verbose == true {
          print("[DEBUG] Already connected, discovering services...")
        }
        peripheral.discoverServices(nil)
      }

      Task { @MainActor [weak self] in
        guard let self = self else { return }

        // Check for encryption errors after a short delay
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        if let op = self.activeOperations[device.id],
          op.continuation != nil && op.encryptionErrors > 0 && op.readingData == nil
        {
          if self.verbose == true {
            print("[DEBUG] Detected encryption errors with no data - pairing required")
          }
          self.failOperation(op, with: AranetError.pairingRequired, disconnect: true)
          return
        }

        // Final timeout after 30 seconds
        try? await Task.sleep(nanoseconds: 25_000_000_000)
        if let op = self.activeOperations[device.id], op.continuation != nil {
          if self.verbose == true {
            print("[DEBUG] Operation timed out after 30 seconds")
          }
          self.failOperation(op, with: AranetError.timeout, disconnect: true)
        }
      }
    }
  }

  /// Monitors an Aranet device with periodic automatic updates.
  ///
  /// Performs an initial reading to determine the device's measurement interval,
  /// then schedules subsequent readings 3 seconds after each expected sensor update.
  /// Multiple devices can be monitored concurrently.
  ///
  /// - Parameter device: The ``AranetDevice`` to monitor, obtained from ``scan(timeout:)``.
  /// - Returns: An async stream of sensor readings.
  @MainActor
  public func monitor(from device: AranetDevice) -> AsyncStream<Result<AranetReading, Error>> {
    return AsyncStream { continuation in
      Task { @MainActor [weak self] in
        guard let self = self else {
          continuation.finish()
          return
        }

        do {
          if self.verbose == true {
            print("[DEBUG] Performing initial reading for monitoring setup...")
          }

          let initialReading = try await self.readCurrentReadings(from: device)
          continuation.yield(.success(initialReading))
          AranetNotifications.postReadingDidUpdate(device: device, reading: initialReading)

          guard let interval = initialReading.interval, let ago = initialReading.ago else {
            continuation.yield(.failure(AranetError.invalidData))
            continuation.finish()
            return
          }

          let timeUntilNextUpdate = Int(interval) - Int(ago)
          let firstReadDelay = timeUntilNextUpdate + 3

          if self.verbose == true {
            print("[DEBUG] Device interval: \(interval)s, ago: \(ago)s")
            print("[DEBUG] Time until next sensor update: \(timeUntilNextUpdate)s")
            print("[DEBUG] First reading in \(firstReadDelay) seconds...")
          }

          await self.monitoringLoop(
            from: device,
            interval: TimeInterval(interval),
            initialDelay: TimeInterval(firstReadDelay),
            continuation: continuation
          )
        } catch {
          if self.verbose == true {
            print("[DEBUG] Initial monitoring read failed: \(error)")
          }
          continuation.yield(.failure(error))
          continuation.finish()
        }
      }
    }
  }

  @MainActor
  private func monitoringLoop(
    from device: AranetDevice,
    interval: TimeInterval,
    initialDelay: TimeInterval,
    continuation: AsyncStream<Result<AranetReading, Error>>.Continuation
  ) async {
    var currentDelay = initialDelay
    var currentInterval = interval

    while Task.isCancelled == false {
      await wait(for: currentDelay)

      if Task.isCancelled == true {
        continuation.finish()
        return
      }

      do {
        if self.verbose == true {
          print("[DEBUG] Reading sensor data...")
        }

        let reading = try await self.readCurrentReadings(from: device)
        continuation.yield(.success(reading))
        AranetNotifications.postReadingDidUpdate(device: device, reading: reading)

        if let newInterval = reading.interval {
          if currentInterval != TimeInterval(newInterval) && self.verbose == true {
            print("[DEBUG] Device interval changed: \(Int(currentInterval))s -> \(newInterval)s")
          }
          currentInterval = TimeInterval(newInterval)
        }

        if let ago = reading.ago {
          let timeUntilNextUpdate = currentInterval - TimeInterval(ago)
          currentDelay = timeUntilNextUpdate + 3.0

          if self.verbose == true {
            print("[DEBUG] Sensor age: \(ago)s, next update in \(Int(timeUntilNextUpdate))s")
            print("[DEBUG] Next reading in \(Int(currentDelay)) seconds...")
          }
        } else {
          currentDelay = currentInterval + 3.0
          if self.verbose == true {
            print("[DEBUG] Age not available, using current interval + 3s")
          }
        }
      } catch {
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

  @MainActor
  private func wait(for delay: TimeInterval) async {
    await withCheckedContinuation { (timerContinuation: CheckedContinuation<Void, Never>) in
      let timer = Timer(timeInterval: delay, repeats: false) { timer in
        timer.invalidate()
        timerContinuation.resume()
      }
      RunLoop.main.add(timer, forMode: .common)
    }
  }

  private func disconnect(_ peripheral: CBPeripheral) {
    centralManager.cancelPeripheralConnection(peripheral)
  }

  private func failOperation(
    _ operation: ReadOperation, with error: Error, disconnect shouldDisconnect: Bool = false
  ) {
    let id = operation.peripheral.identifier
    operation.continuation?.resume(throwing: error)
    operation.continuation = nil
    activeOperations.removeValue(forKey: id)
    if shouldDisconnect == true {
      disconnect(operation.peripheral)
    }
  }

  private func failAllOperations(with error: Error) {
    for (_, operation) in activeOperations {
      operation.continuation?.resume(throwing: error)
      operation.continuation = nil
    }
    activeOperations.removeAll()
  }

  private func completeReading(for operation: ReadOperation) {
    guard let data = operation.readingData else {
      failOperation(operation, with: AranetError.invalidData)
      return
    }

    do {
      let name =
        operation.deviceName.isEmpty
        ? (operation.peripheral.name ?? "Unknown")
        : operation.deviceName
      let reading = try parseReading(
        data: data,
        name: name,
        version: operation.deviceVersion,
        characteristicUUID: operation.readingCharacteristicUUID
      )
      let id = operation.peripheral.identifier
      operation.continuation?.resume(returning: reading)
      operation.continuation = nil
      activeOperations.removeValue(forKey: id)
      disconnect(operation.peripheral)
    } catch {
      failOperation(operation, with: error, disconnect: true)
    }
  }
}

// MARK: - CBCentralManagerDelegate

extension AranetClient: CBCentralManagerDelegate {
  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn {
      bluetoothReadyContinuation?.resume()
      bluetoothReadyContinuation = nil
    } else if central.state == .unauthorized {
      let error = AranetError.bluetoothUnauthorized
      bluetoothReadyContinuation?.resume(throwing: error)
      bluetoothReadyContinuation = nil
      failAllOperations(with: error)
    } else if central.state == .unsupported {
      let error = AranetError.bluetoothUnsupported
      bluetoothReadyContinuation?.resume(throwing: error)
      bluetoothReadyContinuation = nil
      failAllOperations(with: error)
    } else if central.state != .unknown && central.state != .resetting {
      bluetoothReadyContinuation?.resume(throwing: AranetError.bluetoothUnavailable)
      bluetoothReadyContinuation = nil
      failAllOperations(with: AranetError.bluetoothUnavailable)
    }
  }

  // swift-format-ignore: AlwaysUseLowerCamelCase
  public func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    if discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) == false {
      if verbose == true {
        print("[DEBUG] Discovered device: \(peripheral.name ?? "Unknown") (RSSI: \(RSSI) dBm)")
      }
      discoveredPeripherals.append(peripheral)
    }
  }

  public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    if verbose == true {
      print("[DEBUG] Connected to peripheral: \(peripheral.name ?? "Unknown")")
      print("[DEBUG] Discovering services...")
    }
    peripheral.discoverServices(nil)
  }

  public func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    if verbose == true {
      print("[DEBUG] Failed to connect: \(error?.localizedDescription ?? "unknown error")")
    }
    guard let operation = activeOperations[peripheral.identifier] else { return }
    failOperation(operation, with: error ?? AranetError.connectionFailed)
  }

  public func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
  ) {
    if verbose == true {
      print(
        "[DEBUG] Disconnected from peripheral: \(error?.localizedDescription ?? "clean disconnect")"
      )
    }
  }
}

// MARK: - CBPeripheralDelegate

extension AranetClient: CBPeripheralDelegate {
  public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    let id = peripheral.identifier
    guard let operation = activeOperations[id] else { return }

    if verbose == true {
      print("[DEBUG] Discovered services: \(peripheral.services?.count ?? 0)")
    }

    guard error == nil, let services = peripheral.services else {
      if verbose == true {
        print("[DEBUG] Error discovering services: \(error?.localizedDescription ?? "unknown")")
      }
      failOperation(operation, with: error ?? AranetError.readFailed)
      return
    }

    operation.expectedServices = services.count

    for service in services {
      if verbose == true {
        print("[DEBUG] Discovering characteristics for service: \(service.uuid)")
      }
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  public func peripheral(
    _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
  ) {
    let id = peripheral.identifier
    guard let operation = activeOperations[id] else { return }

    operation.servicesDiscovered += 1

    if verbose == true {
      print(
        "[DEBUG] Discovered \(service.characteristics?.count ?? 0) characteristics for service: \(service.uuid)"
      )
      print(
        "[DEBUG] Services discovered: \(operation.servicesDiscovered)/\(operation.expectedServices)"
      )
    }

    guard error == nil, let characteristics = service.characteristics else {
      if verbose == true {
        print(
          "[DEBUG] Error discovering characteristics: \(error?.localizedDescription ?? "unknown")")
      }
      return
    }

    for characteristic in characteristics {
      if verbose == true {
        print(
          "[DEBUG] Found characteristic: \(characteristic.uuid) (properties: \(characteristic.properties.rawValue))"
        )
      }

      if characteristic.uuid == AranetUUID.characteristicDeviceName {
        if verbose == true {
          print("[DEBUG] Reading device name...")
        }
        operation.pendingReads.insert(characteristic.uuid)
        peripheral.readValue(for: characteristic)
      } else if characteristic.uuid == AranetUUID.characteristicSoftwareRevision {
        if verbose == true {
          print("[DEBUG] Reading software revision...")
        }
        operation.pendingReads.insert(characteristic.uuid)
        peripheral.readValue(for: characteristic)
      } else if AranetUUID.readingCharacteristics.contains(characteristic.uuid) {
        if verbose == true {
          print("[DEBUG] Found reading characteristic: \(characteristic.uuid)")
        }
        operation.availableReadingChars.insert(characteristic.uuid)
      }
    }

    // Only check if we've discovered all services
    if operation.servicesDiscovered == operation.expectedServices {
      if verbose == true {
        print(
          "[DEBUG] All services discovered. Available reading characteristics: \(operation.availableReadingChars.count)"
        )
      }

      let readingCharToRead = AranetUUID.readingCharacteristicPriority
        .first { operation.availableReadingChars.contains($0) }

      if verbose == true, let selected = readingCharToRead {
        print("[DEBUG] Will read from characteristic: \(selected)")
      }

      if let readingChar = readingCharToRead {
        operation.readingCharacteristicUUID = readingChar
        for service in peripheral.services ?? [] {
          if let characteristics = service.characteristics {
            for char in characteristics where char.uuid == readingChar {
              operation.pendingReads.insert(char.uuid)
              peripheral.readValue(for: char)
              if verbose == true {
                print("[DEBUG] Reading from \(char.uuid)")
              }
            }
          }
        }
      }

      if verbose == true {
        print("[DEBUG] Pending reads: \(operation.pendingReads.count)")
      }

      if operation.readingData != nil && operation.pendingReads.isEmpty {
        if verbose == true {
          print("[DEBUG] Have reading data and no pending reads, completing...")
        }
        completeReading(for: operation)
      } else if operation.pendingReads.isEmpty {
        if verbose == true {
          print("[DEBUG] All services discovered but no reading characteristics found!")
        }
        failOperation(operation, with: AranetError.readFailed)
      }
    }
  }

  public func peripheral(
    _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    let id = peripheral.identifier
    guard let operation = activeOperations[id] else { return }

    if let error = error {
      let nsError = error as NSError

      if nsError.domain == "CBATTErrorDomain" && nsError.code == 15 {
        if verbose == true {
          print(
            "[DEBUG] Authentication error on characteristic \(characteristic.uuid) - this is expected for F0CD1503, we use F0CD3001 instead"
          )
        }
        operation.pendingReads.remove(characteristic.uuid)
        return
      }

      if verbose == true {
        print(
          "[DEBUG] Error reading characteristic \(characteristic.uuid): \(error.localizedDescription)"
        )
      }
      operation.pendingReads.remove(characteristic.uuid)
      return
    }

    guard let data = characteristic.value else {
      if verbose == true {
        print("[DEBUG] No data returned for characteristic \(characteristic.uuid)")
      }
      operation.pendingReads.remove(characteristic.uuid)

      if AranetUUID.readingCharacteristics.contains(characteristic.uuid) {
        operation.encryptionErrors += 1
        if verbose == true {
          print(
            "[DEBUG] Reading characteristic returned no data - likely needs pairing (count: \(operation.encryptionErrors))"
          )
        }
      }
      return
    }

    if verbose == true {
      print("[DEBUG] Read characteristic \(characteristic.uuid): \(data.count) bytes")
    }

    operation.pendingReads.remove(characteristic.uuid)

    if characteristic.uuid == AranetUUID.characteristicDeviceName {
      operation.deviceName = String(data: data, encoding: .utf8) ?? ""
      if verbose == true {
        print("[DEBUG] Device name: \(operation.deviceName)")
      }
    } else if characteristic.uuid == AranetUUID.characteristicSoftwareRevision {
      operation.deviceVersion = String(data: data, encoding: .utf8) ?? ""
      if verbose == true {
        print("[DEBUG] Software version: \(operation.deviceVersion)")
      }
    } else if AranetUUID.readingCharacteristics.contains(characteristic.uuid) {
      operation.readingData = data
      if verbose == true {
        print(
          "[DEBUG] Got reading data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))"
        )
      }
    }

    if verbose == true {
      print("[DEBUG] Pending reads remaining: \(operation.pendingReads.count)")
    }

    if operation.pendingReads.isEmpty && operation.readingData != nil {
      if verbose == true {
        print("[DEBUG] All reads complete, parsing data...")
      }
      completeReading(for: operation)
    }
  }

  public func peripheral(
    _ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]
  ) {
    if verbose == true {
      print("[DEBUG] Peripheral services were modified")
    }
  }

  public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
    if verbose == true {
      print("[DEBUG] Peripheral ready to send write without response")
    }
  }

  // MARK: - Debug Helpers

  private func printHexDump(
    _ data: Data, title: String, fields: [(range: String, description: String)]
  ) {
    print("[DEBUG] === \(title) (\(data.count) bytes) ===")

    for field in fields {
      let parts = field.range.split(separator: "-")
      guard let start = Int(parts[0]) else { continue }
      let end = parts.count > 1 ? (Int(parts[1]) ?? start) : start

      guard start < data.count else { continue }
      let clampedEnd = min(end, data.count - 1)

      let bytes = data[start...clampedEnd]
      let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")

      var leValue: UInt64 = 0
      for (i, byte) in bytes.enumerated() {
        leValue |= UInt64(byte) << (i * 8)
      }

      let range = field.range.padding(toLength: 5, withPad: " ", startingAt: 0)
      let hexVal = "\(hex) = \(leValue)"
      print(
        "[DEBUG] \(range)  \(hexVal.padding(toLength: 36, withPad: " ", startingAt: 0)) \(field.description)"
      )
    }

    print("[DEBUG] ===")
  }

  private static let aranet4Fields: [(range: String, description: String)] = [
    ("0-1", "CO2 (UInt16 LE, ppm)"),
    ("2-3", "Temperature (UInt16 LE, raw/20)"),
    ("4-5", "Pressure (UInt16 LE, raw/10 hPa)"),
    ("6", "Humidity (UInt8, %)"),
    ("7", "Battery (UInt8, %)"),
    ("8", "Status (0=Err, 1=G, 2=Y, 3=R)"),
    ("9-10", "Interval (UInt16 LE, sec)"),
    ("11-12", "Ago (UInt16 LE, sec)"),
  ]

  private static let radiationFields: [(range: String, description: String)] = [
    ("0-1", "Device type + H"),
    ("2-3", "Interval (UInt16 LE, sec)"),
    ("4-5", "Ago (UInt16 LE, sec)"),
    ("6", "Battery (UInt8, %)"),
    ("7-10", "Rate (UInt32 LE, nSv/h)"),
    ("11-18", "Total (UInt64 LE, nSv)"),
    ("19-26", "Duration (UInt64 LE, sec)"),
    ("27", "Status (0x05=G, 0x0A=Y, 0x0B=R)"),
    ("28-35", "Total dose (UInt64 LE, uSv)"),
    ("36-43", "Realtime duration (UInt64 LE, sec, 60s granularity)"),
    ("44-47", "Reserved (zero)"),
  ]

  // MARK: - Data Parsing

  private func parseReading(data: Data, name: String, version: String, characteristicUUID: CBUUID?)
    throws -> AranetReading
  {
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

    if characteristicUUID == AranetUUID.characteristicCurrentReadingsAR2
      || characteristicUUID == AranetUUID.characteristicCurrentReadingsAR2Detailed
    {
      guard data.count >= 1 else {
        throw AranetError.invalidData
      }

      let deviceTypeByte = readUInt8()
      offset = 0

      if deviceTypeByte == 4 {
        // F0CD1504 (28 bytes): rate stored as nSv/h * 10
        // F0CD3003 (48+ bytes): rate stored as nSv/h directly
        let rateDivisor: Double
        if data.count == 28 {
          rateDivisor = 10.0
        } else if data.count >= 48 {
          rateDivisor = 1.0
        } else {
          throw AranetError.invalidData
        }

        if verbose == true {
          printHexDump(data, title: "Aranet Radiation", fields: Self.radiationFields)
        }

        offset = 2
        let interval = readUInt16LE()
        let ago = readUInt16LE()
        let battery = readUInt8()

        if verbose == true {
          print("[DEBUG] Radiation parsing: interval=\(interval), ago=\(ago), battery=\(battery)")
        }

        let radiationRateRaw = readUInt32LE()
        let radiationTotal = readUInt64LE()
        let radiationDuration = readUInt64LE()

        // Byte 27: status display color (different encoding than Aranet4)
        let statusByte = readUInt8()
        let status = AranetStatusColor.fromRadiationByte(statusByte)
        if verbose == true {
          print(
            "[DEBUG] Radiation status byte: 0x\(String(format: "%02X", statusByte)) -> \(status?.name ?? "unknown")"
          )
        }

        let radiationRate = Measurement(
          value: Double(radiationRateRaw) / rateDivisor,
          unit: UnitRadiationDose.nanosieverts
        )
        let radiationTotalMeasurement = Measurement(
          value: Double(radiationTotal),
          unit: UnitRadiationDose.nanosieverts
        )

        return AranetReading(
          deviceType: .aranetRadiation,
          name: name,
          version: version,
          radiationRate: radiationRate,
          radiationTotal: radiationTotalMeasurement,
          radiationDuration: radiationDuration,
          battery: battery,
          status: status,
          interval: interval,
          ago: ago
        )
      }
      // Aranet2 - first byte = 2
      else if deviceTypeByte == 2 {
        guard data.count >= 10 else {
          throw AranetError.invalidData
        }

        offset = 1
        let interval = readUInt16LE()
        let ago = readUInt16LE()
        let battery = readUInt8()
        let tempRaw = readUInt16LE()
        let humidity = readUInt8()
        let _ = readUInt8()

        let temperatureValue = Double(tempRaw) / 20.0
        let temperature = Measurement(value: temperatureValue, unit: UnitTemperature.celsius)

        return AranetReading(
          deviceType: .aranet2,
          name: name,
          version: version,
          temperature: temperature,
          humidity: humidity,
          battery: battery,
          interval: interval,
          ago: ago
        )
      }
      // Aranet Radon - first byte = 3 (not fully implemented yet)
      else if deviceTypeByte == 3 {
        throw AranetError.invalidData
      } else {
        throw AranetError.invalidData
      }
    }
    // Aranet4 format (F0CD3001 detailed or F0CD1503 basic)
    else {
      guard data.count >= 7 else {
        throw AranetError.invalidData
      }

      if verbose == true {
        printHexDump(data, title: "Aranet4", fields: Self.aranet4Fields)
      }

      offset = 0
      let co2 = readUInt16LE()
      let tempRaw = readUInt16LE()
      let pressureRaw = readUInt16LE()
      let humidity = readUInt8()
      let battery = readUInt8()
      let statusRaw = readUInt8()

      let temperatureValue = Double(tempRaw) / 20.0
      let temperature = Measurement(value: temperatureValue, unit: UnitTemperature.celsius)

      let pressureValue = Double(pressureRaw) / 10.0
      let pressure = Measurement(value: pressureValue, unit: UnitPressure.hectopascals)

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
