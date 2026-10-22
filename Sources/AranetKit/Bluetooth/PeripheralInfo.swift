//
// PeripheralInfo.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// The identity of a peripheral as seen through ``BluetoothCentral``.
struct PeripheralInfo: Sendable, Equatable {
    let id: UUID
    let name: String?

    init(id: UUID, name: String?) {
        self.id = id
        self.name = name
    }
}
