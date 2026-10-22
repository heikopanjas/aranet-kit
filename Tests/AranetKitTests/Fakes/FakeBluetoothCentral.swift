import CoreBluetooth
import Foundation

@testable import AranetKit

/// A `BluetoothCentral` that records the commands it receives and lets tests deliver events synchronously.
@MainActor
final class FakeBluetoothCentral: BluetoothCentral {
    enum Command: Equatable {
        case scan([CBUUID])
        case stopScan
        case retrieve([UUID])
        case connect(UUID)
        case cancelConnection(UUID)
        case discoverServices(UUID)
        case discoverCharacteristics(UUID, CBUUID)
        case readValue(UUID, service: CBUUID, characteristic: CBUUID)
    }

    var eventHandler: (@MainActor (BluetoothEvent) -> Void)?
    var state: CBManagerState = .poweredOn
    var retrievable: [UUID: PeripheralInfo] = [:]
    var connectionStates: [UUID: CBPeripheralState] = [:]
    private(set) var commands: [Command] = []

    /// Delivers an event to the client exactly as a delegate callback would.
    func send(_ event: BluetoothEvent) -> Void {
        self.eventHandler?(event)
    }

    func count(of command: Command) -> Int {
        return self.commands.filter { $0 == command }.count
    }

    func scanForPeripherals(withServices services: [CBUUID]) -> Void {
        self.commands.append(.scan(services))
    }

    func stopScan() -> Void {
        self.commands.append(.stopScan)
    }

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [PeripheralInfo] {
        self.commands.append(.retrieve(identifiers))
        return identifiers.compactMap { self.retrievable[$0] }
    }

    func connectionState(of peripheralId: UUID) -> CBPeripheralState {
        return self.connectionStates[peripheralId] ?? .disconnected
    }

    func connect(_ peripheralId: UUID) -> Void {
        self.commands.append(.connect(peripheralId))
    }

    func cancelConnection(_ peripheralId: UUID) -> Void {
        self.commands.append(.cancelConnection(peripheralId))
    }

    func discoverServices(of peripheralId: UUID) -> Void {
        self.commands.append(.discoverServices(peripheralId))
    }

    func discoverCharacteristics(of peripheralId: UUID, in service: CBUUID) -> Void {
        self.commands.append(.discoverCharacteristics(peripheralId, service))
    }

    func readValue(of characteristic: CBUUID, in service: CBUUID, from peripheralId: UUID) -> Void {
        self.commands.append(.readValue(peripheralId, service: service, characteristic: characteristic))
    }
}
