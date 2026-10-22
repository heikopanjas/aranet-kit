//
// BluetoothEvent.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth
import Foundation

/// A CoreBluetooth delegate callback reduced to the values the client acts on.
///
/// Peripherals, services, and characteristics are identified by their identifiers only, so the
/// events can be produced by a fake central in tests.
enum BluetoothEvent: Sendable {
    case stateChanged(CBManagerState)
    case discovered(PeripheralInfo, rssi: Int)
    case connected(UUID)
    case connectFailed(UUID, (any Error)?)
    case disconnected(UUID, (any Error)?)
    case servicesDiscovered(UUID, [CBUUID], (any Error)?)
    case characteristicsDiscovered(UUID, service: CBUUID, [CBUUID], (any Error)?)
    case valueUpdated(UUID, characteristic: CBUUID, Data?, (any Error)?)
}

/// `CBUUID` is an immutable value object, which makes sharing it across isolation domains safe.
extension CBUUID: @retroactive @unchecked Sendable {}
