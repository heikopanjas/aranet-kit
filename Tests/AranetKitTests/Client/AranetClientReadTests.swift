import CoreBluetooth
import Foundation
import Testing

@testable import AranetKit

@MainActor
@Suite(.tags(.bluetooth), .timeLimit(.minutes(1)), .serialized)
struct AranetClientReadTests {
    private static let saf = AranetUUID.serviceSAFTehnika
    private static let detailed = AranetUUID.characteristicCurrentReadingsDetailed
    private static let paired = AranetUUID.characteristicCurrentReadingsAR2
    private let device = AranetDevice(id: UUID(), name: "Aranet4 1A2B3")

    private var scanServices: FakeBluetoothCentral.Command {
        return .scan([AranetUUID.serviceSAFTehnika, AranetUUID.serviceSAFTehnikaOld])
    }

    private func startRead(_ harness: ClientHarness, of device: AranetDevice? = nil) async -> Task<AranetReading, any Error> {
        let target = device ?? self.device
        let connects = harness.central.count(of: .connect(target.id))
        let sleepers = harness.gate.requestedDelays.count
        let task = Task {
            try await harness.client.readCurrentReadings(from: target)
        }
        await settle("connect requested and watchdog armed") {
            harness.central.count(of: .connect(target.id)) == connects + 1 && harness.gate.requestedDelays.count == sleepers + 1
        }
        return task
    }

    @Test("A complete read returns the parsed reading and disconnects")
    func completeRead() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)

        #expect(harness.central.commands.first == .retrieve([self.device.id]))
        harness.completeAranet4Read(of: self.device.id)
        let reading = try await task.value

        #expect(reading.name == "Aranet4 1A2B3")
        #expect(reading.version == "v1.4.14")
        #expect(reading.co2 == 812)
        #expect(reading.interval == 300)
        #expect(harness.central.commands.contains(.discoverServices(self.device.id)) == true)
        #expect(harness.central.commands.contains(.discoverCharacteristics(self.device.id, Self.saf)) == true)
        #expect(harness.central.commands.contains(.readValue(self.device.id, service: Self.saf, characteristic: Self.detailed)) == true)
        #expect(harness.central.commands.last == .cancelConnection(self.device.id))
        #expect(harness.log.contains("=== Aranet4 (13 bytes) ===") == true)
        await settle("watchdog cancelled") { harness.gate.waiting == 0 }
    }

    @Test("Devices found by a scan are read without resolving them again")
    func scannedDeviceNeedsNoRetrieve() async throws -> Void {
        let harness = ClientHarness()
        let scanTask = Task {
            try await harness.client.scan(timeout: 15)
        }
        await settle("scan started and sleeping") { harness.central.count(of: self.scanServices) == 1 && harness.gate.waiting == 1 }
        harness.central.send(.discovered(PeripheralInfo(id: self.device.id, name: "Aranet4 1A2B3"), rssi: -50))
        harness.gate.release()
        let devices = try await scanTask.value
        let scanned = try #require(devices.first)

        let task = await self.startRead(harness, of: scanned)
        harness.completeAranet4Read(of: scanned.id)
        let reading = try await task.value

        #expect(reading.co2 == 812)
        #expect(harness.central.commands.contains(.retrieve([scanned.id])) == false)
    }

    @Test("Unknown devices that the system cannot resolve throw deviceNotFound")
    func unknownDevice() async -> Void {
        let harness = ClientHarness()

        await #expect(throws: AranetError.deviceNotFound) {
            try await harness.client.readCurrentReadings(from: self.device)
        }
        #expect(harness.central.commands == [.retrieve([self.device.id])])
    }

    @Test("Resolved peripherals are remembered for later reads")
    func resolvedPeripheralIsRemembered() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let firstTask = await self.startRead(harness)
        harness.completeAranet4Read(of: self.device.id)
        _ = try await firstTask.value

        harness.central.retrievable = [:]
        let secondTask = await self.startRead(harness)
        harness.completeAranet4Read(of: self.device.id)
        _ = try await secondTask.value

        #expect(harness.central.count(of: .retrieve([self.device.id])) == 1)
    }

    @Test("An already connected peripheral skips the connect step")
    func alreadyConnectedSkipsConnect() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        harness.central.connectionStates[self.device.id] = .connected
        let task = Task {
            try await harness.client.readCurrentReadings(from: self.device)
        }
        await settle("services requested") { harness.central.count(of: .discoverServices(self.device.id)) == 1 }

        harness.central.send(.servicesDiscovered(self.device.id, [Self.saf], nil))
        harness.central.send(.characteristicsDiscovered(self.device.id, service: Self.saf, [Self.detailed], nil))
        harness.central.send(.valueUpdated(self.device.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))
        let reading = try await task.value

        #expect(reading.name == "Aranet4 1A2B3", "Without a GAP name the advertised name is used")
        #expect(harness.central.count(of: .connect(self.device.id)) == 0)
    }

    @Test("A failed connection throws connectionFailed")
    func connectFailed() async -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)

        harness.central.send(.connectFailed(self.device.id, nil))

        await #expect(throws: AranetError.connectionFailed) {
            try await task.value
        }
    }

    @Test("A disconnect during the read throws connectionFailed at once")
    func disconnectDuringRead() async -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)
        harness.central.send(.connected(self.device.id))

        harness.central.send(.disconnected(self.device.id, nil))

        await #expect(throws: AranetError.connectionFailed) {
            try await task.value
        }
        await settle("watchdog cancelled") { harness.gate.waiting == 0 }
    }

    @Test("Invalid reading data fails the read with invalidData")
    func invalidReadingData() async -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)

        harness.central.send(.connected(self.device.id))
        harness.central.send(.servicesDiscovered(self.device.id, [Self.saf], nil))
        harness.central.send(.characteristicsDiscovered(self.device.id, service: Self.saf, [Self.detailed], nil))
        harness.central.send(.valueUpdated(self.device.id, characteristic: Self.detailed, Data([0x01, 0x02]), nil))

        await #expect(throws: AranetError.invalidData) {
            try await task.value
        }
        #expect(harness.central.commands.last == .cancelConnection(self.device.id))
    }

    @Test("Reading characteristics that refuse encryption report pairingRequired after the pairing check delay")
    func pairingRequired() async -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)
        let encryptionError = NSError(domain: CBATTErrorDomain, code: CBATTError.insufficientEncryption.rawValue)

        harness.central.send(.connected(self.device.id))
        harness.central.send(.servicesDiscovered(self.device.id, [Self.saf], nil))
        harness.central.send(.characteristicsDiscovered(self.device.id, service: Self.saf, [Self.paired], nil))
        harness.central.send(.valueUpdated(self.device.id, characteristic: Self.paired, nil, encryptionError))
        #expect(harness.gate.requestedDelays == [ClientHarness.pairingCheckDelay])
        harness.gate.release()

        await #expect(throws: AranetError.pairingRequired) {
            try await task.value
        }
        #expect(harness.central.commands.last == .cancelConnection(self.device.id))
    }

    @Test("A read that never completes times out")
    func readTimesOut() async -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)
        harness.central.send(.connected(self.device.id))

        harness.gate.release()
        await settle("timeout armed") { harness.gate.requestedDelays.count == 2 }
        #expect(harness.gate.requestedDelays == [ClientHarness.pairingCheckDelay, ClientHarness.readTimeout - ClientHarness.pairingCheckDelay])
        harness.gate.release()

        await #expect(throws: AranetError.timeout) {
            try await task.value
        }
        #expect(harness.log.contains("Operation timed out after 30 seconds") == true)
    }

    @Test("A watchdog from an earlier read never fails a later read of the same device")
    func staleWatchdogIsHarmless() async throws -> Void {
        let harness = ClientHarness()
        harness.gate.honorsCancellation = false
        harness.register(self.device)
        let firstTask = await self.startRead(harness)
        harness.completeAranet4Read(of: self.device.id)
        _ = try await firstTask.value
        #expect(harness.gate.waiting == 1, "The first watchdog ignores its cancellation and keeps sleeping")

        let secondTask = await self.startRead(harness)
        #expect(harness.gate.waiting == 2, "Both watchdogs are sleeping")
        harness.gate.release()
        await settle("second watchdog past pairing check") { harness.gate.requestedDelays.count == 3 }
        harness.completeAranet4Read(of: self.device.id)
        let reading = try await secondTask.value

        #expect(reading.co2 == 812)
        #expect(harness.log.contains("Operation timed out") == false)
    }

    @Test("A second read of a device that is still being read throws operationInProgress")
    func duplicateRead() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)

        await #expect(throws: AranetError.operationInProgress) {
            try await harness.client.readCurrentReadings(from: self.device)
        }

        harness.completeAranet4Read(of: self.device.id)
        _ = try await task.value
    }

    @Test("Reads of different devices run concurrently")
    func concurrentReadsOfDifferentDevices() async throws -> Void {
        let harness = ClientHarness()
        let other = AranetDevice(id: UUID(), name: "Aranet4 OTHER")
        harness.register(self.device)
        harness.register(other)
        let firstTask = await self.startRead(harness)
        let secondTask = await self.startRead(harness, of: other)

        harness.completeAranet4Read(of: other.id, name: "Other")
        harness.completeAranet4Read(of: self.device.id)

        #expect(try await firstTask.value.name == "Aranet4 1A2B3")
        #expect(try await secondTask.value.name == "Other")
    }

    @Test("Bluetooth turning off fails every read in progress")
    func bluetoothOffFailsAllReads() async -> Void {
        let harness = ClientHarness()
        let other = AranetDevice(id: UUID(), name: "Aranet4 OTHER")
        harness.register(self.device)
        harness.register(other)
        let firstTask = await self.startRead(harness)
        let secondTask = await self.startRead(harness, of: other)

        harness.central.send(.stateChanged(.poweredOff))

        await #expect(throws: AranetError.bluetoothUnavailable) {
            try await firstTask.value
        }
        await #expect(throws: AranetError.bluetoothUnavailable) {
            try await secondTask.value
        }
    }

    @Test("Cancelling the caller fails the read with CancellationError and disconnects")
    func cancellationDisconnects() async -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)
        harness.central.send(.connected(self.device.id))

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(harness.central.commands.last == .cancelConnection(self.device.id))
        #expect(harness.log.contains("Read cancelled") == true)
    }

    @Test("Cancelling after completion changes nothing")
    func cancellationAfterCompletion() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)
        harness.completeAranet4Read(of: self.device.id)
        _ = try await task.value
        let commandCount = harness.central.commands.count

        task.cancel()
        await settle("cancellation handled") { harness.log.messages.count >= 0 }

        #expect(harness.central.commands.count == commandCount)
        #expect(harness.log.contains("Read cancelled") == false)
    }

    @Test("Peripherals without a name are logged as Unknown")
    func unnamedPeripheral() async throws -> Void {
        let harness = ClientHarness()
        harness.central.retrievable[self.device.id] = PeripheralInfo(id: self.device.id, name: nil)
        let task = await self.startRead(harness)

        harness.completeAranet4Read(of: self.device.id)
        let reading = try await task.value

        #expect(reading.name == "Aranet4 1A2B3", "The GAP name read during the connection is used")
        #expect(harness.log.contains("Resolved known peripheral without scanning: Unknown") == true)
        #expect(harness.log.contains("Starting read from device: Unknown") == true)
    }

    @Test("A cancellation that loses the race against completion changes nothing")
    func cancellationRacingCompletion() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)

        task.cancel()
        harness.completeAranet4Read(of: self.device.id)
        let reading = try await task.value

        #expect(reading.co2 == 812)
        await settle("cancellation handled") { harness.gate.waiting == 0 }
        #expect(harness.log.contains("Read cancelled") == false)
        #expect(harness.central.count(of: .cancelConnection(self.device.id)) == 1)
    }

    @Test("A read completing after the pairing check cancels the timeout watchdog")
    func completionAfterPairingCheck() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)
        let task = await self.startRead(harness)
        harness.gate.release()
        await settle("timeout armed") { harness.gate.requestedDelays.count == 2 }

        harness.completeAranet4Read(of: self.device.id)
        let reading = try await task.value

        #expect(reading.co2 == 812)
        await settle("watchdog cancelled") { harness.gate.waiting == 0 }
        #expect(harness.log.contains("Operation timed out") == false)
    }

    @Test("A watchdog waking after completion is harmless")
    func lateWatchdogWake() async throws -> Void {
        let harness = ClientHarness()
        harness.gate.honorsCancellation = false
        harness.register(self.device)
        let task = await self.startRead(harness)
        harness.gate.release()
        await settle("timeout armed") { harness.gate.requestedDelays.count == 2 }
        harness.completeAranet4Read(of: self.device.id)
        _ = try await task.value
        #expect(harness.gate.waiting == 1, "The watchdog ignores its cancellation and keeps sleeping")

        harness.gate.release()
        await settle("watchdog returned") { harness.gate.waiting == 0 }

        #expect(harness.log.contains("Operation timed out") == false)
        #expect(harness.central.count(of: .cancelConnection(self.device.id)) == 1)
    }

    @Test("Events for peripherals without a read in progress are ignored")
    func strayEventsAreIgnored() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)

        harness.central.send(.connected(self.device.id))
        harness.central.send(.valueUpdated(self.device.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))

        #expect(harness.central.commands.isEmpty == true)

        let task = await self.startRead(harness)
        harness.completeAranet4Read(of: self.device.id)
        harness.central.send(.valueUpdated(self.device.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))
        _ = try await task.value

        #expect(harness.central.count(of: .cancelConnection(self.device.id)) == 1)
    }
}
