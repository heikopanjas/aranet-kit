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

/// Bluetooth Low Energy client for communicating with Aranet sensor devices.
///
/// `AranetClient` provides a high-level async/await API for discovering, connecting to,
/// and reading data from Aranet Bluetooth sensors (Aranet4, Aranet2, Aranet Radiation,
/// and Aranet Radon Plus). CoreBluetooth is fully encapsulated -- consumers only work
/// with ``AranetDevice`` and ``AranetReading`` types.
///
/// The client is isolated to the main actor: CoreBluetooth delivers on the main queue, and
/// every ``Notification/Name/aranetReadingDidUpdate`` notification is posted from the main actor.
/// Each read operation keeps its own state, so simultaneous reads do not interfere with each other.
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
@MainActor
public final class AranetClient {
    /// Suspends for the given number of seconds; injected so tests control time.
    public typealias Sleep = @MainActor (TimeInterval) async throws -> Void

    /// Seconds to wait for Bluetooth to power on before a scan or read fails.
    public static let defaultReadyTimeout: TimeInterval = 5
    /// Seconds after which a read whose reading characteristics refused encryption is reported as needing pairing.
    public static let defaultPairingCheckDelay: TimeInterval = 5
    /// Seconds after which a read that has not completed fails with a timeout.
    public static let defaultReadTimeout: TimeInterval = 30
    /// Seconds a scan runs when no timeout is given.
    public static let defaultScanTimeout: TimeInterval = 15

    /// Echoes diagnostics to standard output when true. Diagnostics always go to the log sink.
    public var verbose: Bool = false

    private let central: any BluetoothCentral
    private let sleep: Sleep
    private let logSink: AranetLog.Sink
    private let readyTimeout: TimeInterval
    private let pairingCheckDelay: TimeInterval
    private let readTimeout: TimeInterval

    private var readyWaiters = WaiterRegistry<Void>()
    private var scanTask: Task<[PeripheralInfo], Never>?
    private var discoveredPeripherals: [PeripheralInfo] = []
    private var knownPeripherals: [UUID: PeripheralInfo] = [:]
    private var operations: [UUID: ReadOperation] = [:]

    /// Creates a client backed by CoreBluetooth. Constructing it triggers the system Bluetooth permission prompt.
    public convenience init() {
        self.init(central: CoreBluetoothCentral())
    }

    init(
        central: any BluetoothCentral,
        log: @escaping AranetLog.Sink = AranetLog.standard,
        readyTimeout: TimeInterval = AranetClient.defaultReadyTimeout,
        pairingCheckDelay: TimeInterval = AranetClient.defaultPairingCheckDelay,
        readTimeout: TimeInterval = AranetClient.defaultReadTimeout,
        sleep: @escaping Sleep = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.central = central
        self.logSink = log
        self.readyTimeout = readyTimeout
        self.pairingCheckDelay = pairingCheckDelay
        self.readTimeout = readTimeout
        self.sleep = sleep
        self.central.eventHandler = { [weak self] event in
            self?.handle(event)
        }
    }

    // MARK: - Public Methods

    /// Scans for nearby Aranet Bluetooth devices.
    ///
    /// A scan started while another scan is running joins it and receives the same result.
    /// Cancelling the calling task stops the scan early and throws `CancellationError`.
    ///
    /// - Parameter timeout: Maximum time to scan in seconds. Default is 15.0 seconds.
    /// - Returns: Array of discovered ``AranetDevice`` values.
    /// - Throws: ``AranetError`` if Bluetooth is unavailable or unauthorized.
    public func scan(timeout: TimeInterval = AranetClient.defaultScanTimeout) async throws -> [AranetDevice] {
        try await self.waitForBluetoothReady()

        let task: Task<[PeripheralInfo], Never>
        if let inFlight = self.scanTask {
            self.log("Joining the scan already in progress")
            task = inFlight
        }
        else {
            task = self.startScan(timeout: timeout)
        }

        let peripherals = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        try Task.checkCancellation()

        for peripheral in peripherals {
            self.knownPeripherals[peripheral.id] = peripheral
        }
        return peripherals.map { AranetDevice(id: $0.id, name: $0.name ?? "Unknown") }
    }

    /// Reads current sensor measurements from an Aranet device.
    ///
    /// Connects to the specified device, discovers its services and characteristics,
    /// then reads the current sensor data. Supports concurrent reads from multiple devices.
    /// Devices that were not discovered by this client are resolved through the system's
    /// known peripherals, so a stored identifier can be read without scanning first.
    ///
    /// - Parameter device: The ``AranetDevice`` to read from.
    /// - Returns: An ``AranetReading`` containing all available sensor measurements.
    /// - Throws: ``AranetError`` for connection, read, or timeout failures, or
    ///   ``AranetError/operationInProgress`` when a read of the same device is still running.
    public func readCurrentReadings(from device: AranetDevice) async throws -> AranetReading {
        try await self.waitForBluetoothReady()

        guard let peripheral = self.resolvePeripheral(device.id) else {
            self.log("Device not known: \(device.id)")
            throw AranetError.deviceNotFound
        }
        guard self.operations[device.id] == nil else {
            throw AranetError.operationInProgress
        }

        let operation = ReadOperation(session: ReadSession(peripheralId: device.id, peripheralName: peripheral.name))
        self.operations[device.id] = operation
        self.log("Starting read from device: \(peripheral.name ?? "Unknown") (\(device.id))")

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AranetReading, any Error>) in
                operation.continuation = continuation
                operation.watchdog = self.startWatchdog(for: operation)

                if self.central.connectionState(of: device.id) == .connected {
                    self.log("Already connected, discovering services...")
                    self.execute([.discoverServices], for: operation)
                }
                else {
                    self.log("Connecting to peripheral...")
                    self.central.connect(device.id)
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.cancel(operation)
            }
        }
    }

    /// Monitors an Aranet device with periodic automatic updates.
    ///
    /// Performs an initial reading to determine the device's measurement interval,
    /// then schedules subsequent readings shortly after each expected sensor update.
    /// Multiple devices can be monitored concurrently.
    ///
    /// The stream finishes after the first failed read. Ending the iteration, by cancelling the consuming task or by
    /// releasing the stream, stops the monitoring loop and its Bluetooth activity.
    ///
    /// - Parameter device: The ``AranetDevice`` to monitor.
    /// - Returns: An async stream of sensor readings.
    public func monitor(from device: AranetDevice) -> AsyncStream<Result<AranetReading, any Error>> {
        let (stream, continuation) = AsyncStream.makeStream(of: Result<AranetReading, any Error>.self)
        let monitor = ReadingMonitor(
            read: { device in
                self.log("Reading sensor data...")
                return try await self.readCurrentReadings(from: device)
            },
            sleep: self.sleep,
            publish: { device, reading in
                AranetNotifications.postReadingDidUpdate(device: device, reading: reading)
            }
        )
        let task = Task {
            await monitor.run(for: device, into: continuation)
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
        return stream
    }

    // MARK: - Bluetooth readiness

    private func waitForBluetoothReady() async throws -> Void {
        let state = self.central.state
        self.log("Checking Bluetooth state: \(state.rawValue)")

        if state == .poweredOn {
            return
        }
        if let error = Self.error(for: state) {
            throw error
        }

        self.log("Waiting for Bluetooth to power on...")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            self.readyWaiters.add(continuation)
            if self.readyWaiters.count == 1 {
                self.startReadyTimeout()
            }
        }
    }

    private func startReadyTimeout() -> Void {
        Task {
            do {
                try await self.sleep(self.readyTimeout)
            }
            catch {
                return
            }

            guard self.readyWaiters.isEmpty == false else { return }
            self.log("Bluetooth ready timeout")
            self.readyWaiters.resumeAll(throwing: AranetError.bluetoothUnavailable)
        }
    }

    /// The error a state implies, or `nil` while Bluetooth is usable or still starting up.
    private static func error(for state: CBManagerState) -> AranetError? {
        if state == .poweredOn || state == .unknown || state == .resetting {
            return nil
        }
        if state == .unauthorized {
            return .bluetoothUnauthorized
        }
        if state == .unsupported {
            return .bluetoothUnsupported
        }
        return .bluetoothUnavailable
    }

    // MARK: - Scanning

    private func startScan(timeout: TimeInterval) -> Task<[PeripheralInfo], Never> {
        self.discoveredPeripherals = []
        self.log("Starting BLE scan for \(timeout) seconds...")
        self.central.scanForPeripherals(withServices: [AranetUUID.serviceSAFTehnika, AranetUUID.serviceSAFTehnikaOld])

        let task = Task { () -> [PeripheralInfo] in
            do {
                try await self.sleep(timeout)
            }
            catch {
                self.log("Scan stopped early")
            }
            self.central.stopScan()
            self.scanTask = nil
            return self.discoveredPeripherals
        }
        self.scanTask = task
        return task
    }

    private func resolvePeripheral(_ id: UUID) -> PeripheralInfo? {
        if let known = self.knownPeripherals[id] {
            return known
        }

        guard let retrieved = self.central.retrievePeripherals(withIdentifiers: [id]).first else {
            return nil
        }
        self.log("Resolved known peripheral without scanning: \(retrieved.name ?? "Unknown")")
        self.knownPeripherals[id] = retrieved
        return retrieved
    }

    // MARK: - Events

    private func handle(_ event: BluetoothEvent) -> Void {
        switch event {
            case .stateChanged(let state):
                self.handleStateChange(state)
            case .discovered(let peripheral, let rssi):
                self.handleDiscovery(of: peripheral, rssi: rssi)
            case .connected, .connectFailed, .disconnected, .servicesDiscovered, .characteristicsDiscovered, .valueUpdated:
                if let id = event.peripheralId {
                    self.route(event, to: id)
                }
        }
    }

    private func handleStateChange(_ state: CBManagerState) -> Void {
        self.log("Bluetooth state changed: \(state.rawValue)")

        if state == .poweredOn {
            self.readyWaiters.resumeAll(returning: ())
            return
        }
        guard let error = Self.error(for: state) else { return }

        self.readyWaiters.resumeAll(throwing: error)
        self.failAllOperations(with: error)
    }

    private func handleDiscovery(of peripheral: PeripheralInfo, rssi: Int) -> Void {
        self.knownPeripherals[peripheral.id] = peripheral
        guard self.discoveredPeripherals.contains(where: { $0.id == peripheral.id }) == false else { return }

        self.log("Discovered device: \(peripheral.name ?? "Unknown") (RSSI: \(rssi) dBm)")
        self.discoveredPeripherals.append(peripheral)
    }

    private func route(_ event: BluetoothEvent, to peripheralId: UUID) -> Void {
        guard let operation = self.operations[peripheralId] else { return }

        let commands = operation.session.handle(event)
        self.execute(commands, for: operation)
    }

    // MARK: - Read operations

    private func execute(_ commands: [ReadCommand], for operation: ReadOperation) -> Void {
        let id = operation.session.peripheralId

        for command in commands {
            switch command {
                case .discoverServices:
                    self.log("Discovering services...")
                    self.central.discoverServices(of: id)
                case .discoverCharacteristics(let service):
                    self.log("Discovering characteristics for service: \(service)")
                    self.central.discoverCharacteristics(of: id, in: service)
                case .read(let service, let characteristic):
                    self.log("Reading characteristic \(characteristic)")
                    self.central.readValue(of: characteristic, in: service, from: id)
                case .complete(let data, let name, let version):
                    self.complete(operation, data: data, name: name, version: version)
                case .fail(let error):
                    self.log("Read failed: \(error)")
                    self.finish(operation, with: .failure(error))
            }
        }
    }

    private func complete(_ operation: ReadOperation, data: Data, name: String, version: String) -> Void {
        let characteristic = operation.session.readingCharacteristic
        self.log("Got reading data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        for line in AranetPayloadParser.hexDumpLines(for: data, characteristic: characteristic) {
            self.log(line)
        }

        do {
            let reading = try AranetPayloadParser.reading(from: data, characteristic: characteristic, name: name, version: version)
            self.finish(operation, with: .success(reading))
        }
        catch {
            self.finish(operation, with: .failure(error))
        }
    }

    private func finish(_ operation: ReadOperation, with result: Result<AranetReading, any Error>) -> Void {
        let id = operation.session.peripheralId
        operation.watchdog?.cancel()
        operation.watchdog = nil

        if let continuation = operation.continuation {
            operation.continuation = nil
            continuation.resume(with: result)
        }
        if self.operations[id] === operation {
            self.operations[id] = nil
        }
        self.central.cancelConnection(id)
    }

    private func isActive(_ operation: ReadOperation) -> Bool {
        return self.operations[operation.session.peripheralId] === operation && operation.continuation != nil
    }

    private func cancel(_ operation: ReadOperation) -> Void {
        guard self.isActive(operation) == true else { return }

        self.log("Read cancelled")
        self.finish(operation, with: .failure(CancellationError()))
    }

    private func failAllOperations(with error: any Error) -> Void {
        let operations = Array(self.operations.values)
        for operation in operations {
            self.finish(operation, with: .failure(error))
        }
    }

    private func startWatchdog(for operation: ReadOperation) -> Task<Void, Never> {
        return Task {
            do {
                try await self.sleep(self.pairingCheckDelay)
            }
            catch {
                return
            }
            guard self.isActive(operation) == true else { return }

            if operation.session.isPairingSuspected == true {
                self.log("Detected encryption errors with no data - pairing required")
                self.finish(operation, with: .failure(AranetError.pairingRequired))
                return
            }

            do {
                try await self.sleep(self.readTimeout - self.pairingCheckDelay)
            }
            catch {
                return
            }
            guard self.isActive(operation) == true else { return }

            self.log("Operation timed out after \(Int(self.readTimeout)) seconds")
            self.finish(operation, with: .failure(AranetError.timeout))
        }
    }

    // MARK: - Diagnostics

    private func log(_ message: String) -> Void {
        self.logSink(message)
        if self.verbose == true {
            print("[DEBUG] \(message)")
        }
    }
}

extension AranetClient: SensorClient {}

extension BluetoothEvent {
    /// The peripheral an event belongs to, or `nil` for central-level events.
    var peripheralId: UUID? {
        switch self {
            case .stateChanged, .discovered:
                return nil
            case .connected(let id):
                return id
            case .connectFailed(let id, _):
                return id
            case .disconnected(let id, _):
                return id
            case .servicesDiscovered(let id, _, _):
                return id
            case .characteristicsDiscovered(let id, _, _, _):
                return id
            case .valueUpdated(let id, _, _, _):
                return id
        }
    }
}
