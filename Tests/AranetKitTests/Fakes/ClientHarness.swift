import CoreBluetooth
import Foundation

@testable import AranetKit

/// Records every diagnostic line the client emits.
@MainActor
final class LogRecorder {
    private(set) var messages: [String] = []

    func record(_ message: String) -> Void {
        self.messages.append(message)
    }

    func contains(_ fragment: String) -> Bool {
        return self.messages.contains { $0.contains(fragment) }
    }
}

/// An `AranetClient` wired to a fake central, a controllable clock, and a log recorder.
@MainActor
final class ClientHarness {
    static let readyTimeout: TimeInterval = 5
    static let pairingCheckDelay: TimeInterval = 5
    static let readTimeout: TimeInterval = 30

    let central = FakeBluetoothCentral()
    let gate = SleepGate()
    let log = LogRecorder()
    let client: AranetClient

    init(state: CBManagerState = .poweredOn) {
        let gate = self.gate
        let log = self.log
        self.central.state = state
        self.client = AranetClient(
            central: self.central,
            log: { log.record($0) },
            readyTimeout: Self.readyTimeout,
            pairingCheckDelay: Self.pairingCheckDelay,
            readTimeout: Self.readTimeout,
            sleep: { try await gate.sleep($0) }
        )
    }

    /// Makes `device` resolvable without a scan.
    func register(_ device: AranetDevice) -> Void {
        self.central.retrievable[device.id] = PeripheralInfo(id: device.id, name: device.name)
    }

    /// Replays the delegate events of a complete Aranet4 read over F0CD3001.
    func completeAranet4Read(of id: UUID, name: String = "Aranet4 1A2B3", version: String = "v1.4.14") -> Void {
        self.central.send(.connected(id))
        self.central.send(.servicesDiscovered(id, [AranetUUID.serviceGAP, AranetUUID.serviceDIS, AranetUUID.serviceSAFTehnika], nil))
        self.central.send(.characteristicsDiscovered(id, service: AranetUUID.serviceGAP, [AranetUUID.characteristicDeviceName], nil))
        self.central.send(.characteristicsDiscovered(id, service: AranetUUID.serviceDIS, [AranetUUID.characteristicSoftwareRevision], nil))
        self.central.send(
            .characteristicsDiscovered(
                id,
                service: AranetUUID.serviceSAFTehnika,
                [AranetUUID.characteristicCurrentReadingsDetailed, AranetUUID.characteristicCurrentReadings],
                nil
            )
        )
        self.central.send(.valueUpdated(id, characteristic: AranetUUID.characteristicDeviceName, Data(name.utf8), nil))
        self.central.send(.valueUpdated(id, characteristic: AranetUUID.characteristicSoftwareRevision, Data(version.utf8), nil))
        let detailed = AranetUUID.characteristicCurrentReadingsDetailed
        self.central.send(.valueUpdated(id, characteristic: detailed, PayloadFixtures.aranet4Detailed, nil))
    }
}
