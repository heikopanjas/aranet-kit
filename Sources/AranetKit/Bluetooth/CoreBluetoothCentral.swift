//
// CoreBluetoothCentral.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth
import Foundation

/// The production ``BluetoothCentral``: owns the `CBCentralManager` and forwards delegate callbacks as events.
///
/// This file is excluded from the coverage gate (see `Scripts/check-coverage.sh`): its delegate methods take
/// `CBPeripheral`, `CBService`, and `CBCharacteristic` arguments that cannot be created in a test process, and
/// constructing the manager triggers the Bluetooth permission prompt. It also hosts the public ``AranetClient/init()``
/// for the same reason. Keep it to pure forwarding and verify it with the hardware checklist in `TEST_PLAN.md`.
@MainActor
final class CoreBluetoothCentral: NSObject, BluetoothCentral {
    var eventHandler: (@MainActor (BluetoothEvent) -> Void)?

    private let manager: CBCentralManager
    private var peripherals: [UUID: CBPeripheral] = [:]

    override init() {
        self.manager = CBCentralManager(delegate: nil, queue: .main)
        super.init()
        self.manager.delegate = self
    }

    var state: CBManagerState {
        return self.manager.state
    }

    func scanForPeripherals(withServices services: [CBUUID]) -> Void {
        self.manager.scanForPeripherals(withServices: services, options: nil)
    }

    func stopScan() -> Void {
        self.manager.stopScan()
    }

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [PeripheralInfo] {
        let retrieved = self.manager.retrievePeripherals(withIdentifiers: identifiers)
        for peripheral in retrieved {
            self.peripherals[peripheral.identifier] = peripheral
        }
        return retrieved.map { PeripheralInfo(id: $0.identifier, name: $0.name) }
    }

    func connectionState(of peripheralId: UUID) -> CBPeripheralState {
        return self.peripherals[peripheralId]?.state ?? .disconnected
    }

    func connect(_ peripheralId: UUID) -> Void {
        guard let peripheral = self.peripherals[peripheralId] else { return }
        peripheral.delegate = self
        let options: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ]
        self.manager.connect(peripheral, options: options)
    }

    func cancelConnection(_ peripheralId: UUID) -> Void {
        guard let peripheral = self.peripherals[peripheralId] else { return }
        self.manager.cancelPeripheralConnection(peripheral)
    }

    func discoverServices(of peripheralId: UUID) -> Void {
        guard let peripheral = self.peripherals[peripheralId] else { return }
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func discoverCharacteristics(of peripheralId: UUID, in service: CBUUID) -> Void {
        guard let peripheral = self.peripherals[peripheralId],
            let cbService = peripheral.services?.first(where: { $0.uuid == service })
        else { return }
        peripheral.discoverCharacteristics(nil, for: cbService)
    }

    func readValue(of characteristic: CBUUID, in service: CBUUID, from peripheralId: UUID) -> Void {
        guard let peripheral = self.peripherals[peripheralId],
            let cbService = peripheral.services?.first(where: { $0.uuid == service }),
            let cbCharacteristic = cbService.characteristics?.first(where: { $0.uuid == characteristic })
        else { return }
        peripheral.readValue(for: cbCharacteristic)
    }

    private func emit(_ event: BluetoothEvent) -> Void {
        self.eventHandler?(event)
    }
}

// MARK: - CBCentralManagerDelegate
//
// The manager delivers on the main queue, so every callback can assume main-actor isolation.

extension CoreBluetoothCentral: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        MainActor.assumeIsolated {
            self.emit(.stateChanged(state))
        }
    }

    // swift-format-ignore: AlwaysUseLowerCamelCase
    nonisolated func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        let info = PeripheralInfo(id: peripheral.identifier, name: peripheral.name)
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            self.peripherals[info.id] = peripheral
            self.emit(.discovered(info, rssi: rssi))
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier
        MainActor.assumeIsolated {
            self.emit(.connected(id))
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        let id = peripheral.identifier
        MainActor.assumeIsolated {
            self.emit(.connectFailed(id, error))
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        let id = peripheral.identifier
        MainActor.assumeIsolated {
            self.emit(.disconnected(id, error))
        }
    }
}

// MARK: - CBPeripheralDelegate

extension CoreBluetoothCentral: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        let id = peripheral.identifier
        let services = (peripheral.services ?? []).map(\.uuid)
        MainActor.assumeIsolated {
            self.emit(.servicesDiscovered(id, services, error))
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        let id = peripheral.identifier
        let serviceId = service.uuid
        let characteristics = (service.characteristics ?? []).map(\.uuid)
        MainActor.assumeIsolated {
            self.emit(.characteristicsDiscovered(id, service: serviceId, characteristics, error))
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        let id = peripheral.identifier
        let characteristicId = characteristic.uuid
        let value = characteristic.value
        MainActor.assumeIsolated {
            self.emit(.valueUpdated(id, characteristic: characteristicId, value, error))
        }
    }
}

extension AranetClient {
    /// Creates a client backed by CoreBluetooth. Constructing it triggers the system Bluetooth permission prompt.
    public convenience init() {
        self.init(central: CoreBluetoothCentral())
    }

    /// Creates the production client for callers that inject a ``SensorClient``, such as `aranet-cli`.
    public nonisolated static let makeLive: @MainActor @Sendable () -> any SensorClient = {
        return AranetClient()
    }
}
