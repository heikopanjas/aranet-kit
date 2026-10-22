//
// BluetoothCentral.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth
import Foundation

/// The subset of CoreBluetooth that ``AranetClient`` drives, expressed with identifiers instead of objects.
///
/// ``CoreBluetoothCentral`` is the production implementation. Tests use a fake that records the
/// commands it receives and delivers ``BluetoothEvent`` values through ``eventHandler``.
@MainActor
protocol BluetoothCentral: AnyObject {
    /// Receives every delegate callback; set once by the client.
    var eventHandler: (@MainActor (BluetoothEvent) -> Void)? { get set }

    var state: CBManagerState { get }

    func scanForPeripherals(withServices services: [CBUUID]) -> Void
    func stopScan() -> Void

    /// Resolves peripherals the system already knows without scanning.
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [PeripheralInfo]

    func connectionState(of peripheralId: UUID) -> CBPeripheralState
    func connect(_ peripheralId: UUID) -> Void
    func cancelConnection(_ peripheralId: UUID) -> Void

    func discoverServices(of peripheralId: UUID) -> Void
    func discoverCharacteristics(of peripheralId: UUID, in service: CBUUID) -> Void
    func readValue(of characteristic: CBUUID, in service: CBUUID, from peripheralId: UUID) -> Void
}
