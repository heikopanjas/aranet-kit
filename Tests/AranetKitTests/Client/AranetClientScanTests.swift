import CoreBluetooth
import Foundation
import Testing

@testable import AranetKit

@MainActor
@Suite(.tags(.bluetooth), .timeLimit(.minutes(1)), .serialized)
struct AranetClientScanTests {
    private let first = PeripheralInfo(id: UUID(), name: "Aranet4 1A2B3")
    private let second = PeripheralInfo(id: UUID(), name: nil)
    private let scanCommand = FakeBluetoothCentral.Command.scan([AranetUUID.serviceSAFTehnika, AranetUUID.serviceSAFTehnikaOld])

    private func startScan(_ harness: ClientHarness, timeout: TimeInterval = 15) async -> Task<[AranetDevice], any Error> {
        let task = Task {
            try await harness.client.scan(timeout: timeout)
        }
        await settle("scan started and sleeping") {
            harness.central.count(of: self.scanCommand) == 1 && harness.gate.requestedDelays.contains(timeout)
        }
        return task
    }

    @Test("A scan on a powered-on central returns the discovered devices after the timeout")
    func scanReturnsDiscoveredDevices() async throws -> Void {
        let harness = ClientHarness()
        let task = await self.startScan(harness, timeout: 7)

        harness.central.send(.discovered(self.first, rssi: -50))
        harness.central.send(.discovered(self.first, rssi: -48))
        harness.central.send(.discovered(self.second, rssi: -70))
        #expect(harness.gate.requestedDelays == [7])
        harness.gate.release()

        let devices = try await task.value

        #expect(devices == [AranetDevice(id: self.first.id, name: "Aranet4 1A2B3"), AranetDevice(id: self.second.id, name: "Unknown")])
        #expect(harness.central.commands.last == .stopScan)
        #expect(harness.log.contains("Discovered device: Aranet4 1A2B3 (RSSI: -50 dBm)") == true)
        #expect(harness.log.messages.filter { $0.contains("Discovered device") }.count == 2, "Duplicate discoveries are not logged twice")
    }

    @Test("Concurrent scans share one Bluetooth scan and both receive the result")
    func concurrentScansShareOneScan() async throws -> Void {
        let harness = ClientHarness()
        let firstTask = await self.startScan(harness)
        let secondTask = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("second caller joined") { harness.log.contains("Joining the scan already in progress") }

        harness.central.send(.discovered(self.first, rssi: -50))
        harness.gate.release()

        let firstDevices = try await firstTask.value
        let secondDevices = try await secondTask.value

        #expect(firstDevices == secondDevices)
        #expect(firstDevices.count == 1)
        #expect(harness.central.count(of: self.scanCommand) == 1)
        #expect(harness.central.count(of: .stopScan) == 1)
    }

    @Test("A later scan after the first finished starts a new Bluetooth scan")
    func sequentialScansStartNewScans() async throws -> Void {
        let harness = ClientHarness()
        let firstTask = await self.startScan(harness)
        harness.gate.release()
        _ = try await firstTask.value

        let secondTask = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("second scan started and sleeping") { harness.central.count(of: self.scanCommand) == 2 && harness.gate.waiting == 1 }
        harness.central.send(.discovered(self.second, rssi: -60))
        harness.gate.release()

        let devices = try await secondTask.value

        #expect(devices.map(\.id) == [self.second.id], "A new scan starts from an empty discovery list")
    }

    @Test("A scan waits for Bluetooth to power on")
    func scanWaitsForPowerOn() async throws -> Void {
        let harness = ClientHarness(state: .unknown)
        let task = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("ready timeout armed") { harness.gate.requestedDelays == [ClientHarness.readyTimeout] }
        #expect(harness.central.commands.isEmpty == true)

        harness.central.state = .poweredOn
        harness.central.send(.stateChanged(.poweredOn))
        await settle("scan started and sleeping") { harness.central.count(of: self.scanCommand) == 1 && harness.gate.waiting == 2 }
        harness.central.send(.discovered(self.first, rssi: -50))
        harness.gate.release()

        let devices = try await task.value

        #expect(devices.count == 1)
        #expect(harness.log.contains("Waiting for Bluetooth to power on...") == true)
    }

    @Test("Waiting for Bluetooth gives up after the ready timeout")
    func readyTimeout() async -> Void {
        let harness = ClientHarness(state: .resetting)
        let task = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("ready timeout armed") { harness.gate.waiting == 1 }

        harness.gate.release()

        await #expect(throws: AranetError.bluetoothUnavailable) {
            try await task.value
        }
        #expect(harness.log.contains("Bluetooth ready timeout") == true)
    }

    @Test("An interrupted ready timeout leaves the waiting caller alone")
    func interruptedReadyTimeout() async throws -> Void {
        let harness = ClientHarness(state: .unknown)
        let task = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("ready timeout armed") { harness.gate.waiting == 1 }

        harness.gate.interrupt()
        await settle("ready timeout gone") { harness.gate.waiting == 0 }
        #expect(harness.log.contains("Bluetooth ready timeout") == false)

        harness.central.state = .poweredOn
        harness.central.send(.stateChanged(.poweredOn))
        await settle("scan sleeping") { harness.gate.waiting == 1 }
        harness.gate.release()

        #expect(try await task.value == [])
    }

    @Test("Two callers waiting for Bluetooth are both released by one state change")
    func multipleReadyWaiters() async throws -> Void {
        let harness = ClientHarness(state: .unknown)
        let firstTask = Task {
            try await harness.client.scan(timeout: 15)
        }
        let secondTask = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("both callers waiting and the ready timeout armed") {
            harness.log.messages.filter { $0 == "Waiting for Bluetooth to power on..." }.count == 2 && harness.gate.waiting == 1
        }
        #expect(harness.gate.requestedDelays == [ClientHarness.readyTimeout], "Only one ready timeout is armed")

        harness.central.state = .poweredOn
        harness.central.send(.stateChanged(.poweredOn))
        await settle("scan started") { harness.central.count(of: .stopScan) == 0 && harness.gate.waiting == 2 }
        harness.gate.release()

        #expect(try await firstTask.value == [])
        #expect(try await secondTask.value == [])
    }

    @Test("The ready timeout is harmless once Bluetooth powered on in time")
    func readyTimeoutAfterPowerOn() async throws -> Void {
        let harness = ClientHarness(state: .unknown)
        let task = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("ready timeout armed") { harness.gate.waiting == 1 }
        harness.central.state = .poweredOn
        harness.central.send(.stateChanged(.poweredOn))
        await settle("scan sleeping") { harness.gate.waiting == 2 }

        harness.gate.release()

        #expect(try await task.value == [])
        #expect(harness.log.contains("Bluetooth ready timeout") == false)
    }

    @Test(
        "Unusable Bluetooth states fail immediately",
        arguments: zip(
            [CBManagerState.unauthorized, .unsupported, .poweredOff],
            [AranetError.bluetoothUnauthorized, .bluetoothUnsupported, .bluetoothUnavailable]
        )
    )
    func unusableStatesFailImmediately(state: CBManagerState, expected: AranetError) async -> Void {
        let harness = ClientHarness(state: state)

        await #expect(throws: expected) {
            try await harness.client.scan(timeout: 15)
        }
        #expect(harness.central.commands.isEmpty == true)
    }

    @Test(
        "A state change to an unusable state fails waiting callers",
        arguments: zip(
            [CBManagerState.unauthorized, .unsupported, .poweredOff],
            [AranetError.bluetoothUnauthorized, .bluetoothUnsupported, .bluetoothUnavailable]
        )
    )
    func stateChangeFailsWaiters(state: CBManagerState, expected: AranetError) async -> Void {
        let harness = ClientHarness(state: .unknown)
        let task = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("caller waiting") { harness.gate.waiting == 1 }

        harness.central.send(.stateChanged(state))

        await #expect(throws: expected) {
            try await task.value
        }
    }

    @Test("Transitional state changes keep callers waiting")
    func transitionalStatesKeepWaiting() async throws -> Void {
        let harness = ClientHarness(state: .unknown)
        let task = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("caller waiting") { harness.gate.waiting == 1 }

        harness.central.send(.stateChanged(.resetting))
        harness.central.send(.stateChanged(.unknown))
        #expect(harness.gate.waiting == 1)

        harness.central.state = .poweredOn
        harness.central.send(.stateChanged(.poweredOn))
        await settle("scan sleeping") { harness.gate.waiting == 2 }
        harness.gate.release()

        #expect(try await task.value == [])
    }

    @Test("Cancelling the caller stops the scan early and throws CancellationError")
    func cancellationStopsScan() async -> Void {
        let harness = ClientHarness()
        let task = await self.startScan(harness)
        harness.central.send(.discovered(self.first, rssi: -50))

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(harness.central.commands.last == .stopScan)
        #expect(harness.log.contains("Scan stopped early") == true)
    }

    @Test("Verbose mode echoes diagnostics to standard output")
    func verboseEchoesDiagnostics() async throws -> Void {
        let harness = ClientHarness()
        harness.client.verbose = true
        let task = await self.startScan(harness)
        harness.gate.release()

        _ = try await task.value

        #expect(harness.client.verbose == true)
        #expect(harness.log.contains("Starting BLE scan for 15.0 seconds...") == true)
    }

    @Test("The default timeouts match the documented values")
    func defaultTimeouts() -> Void {
        #expect(AranetClient.defaultScanTimeout == 15)
        #expect(AranetClient.defaultReadyTimeout == 5)
        #expect(AranetClient.defaultPairingCheckDelay == 5)
        #expect(AranetClient.defaultReadTimeout == 30)
    }
}
