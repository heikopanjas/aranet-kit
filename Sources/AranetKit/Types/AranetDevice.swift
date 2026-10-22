//
// AranetDevice.swift
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

import Foundation

/// A discovered Aranet Bluetooth device.
///
/// This type abstracts away CoreBluetooth internals so consumers never need
/// to import CoreBluetooth. Instances are created by ``AranetClient/scan(timeout:)``
/// and passed back to ``AranetClient/readCurrentReadings(from:)`` or
/// ``AranetClient/monitor(from:)``.
public struct AranetDevice: Identifiable, Hashable, Sendable {
    /// The device's unique Bluetooth identifier.
    public let id: UUID

    /// The device's advertised Bluetooth name (e.g. "Aranet4 1A2B3C").
    public let name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
