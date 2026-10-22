//
// JsonDevice.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit

/// A discovered Aranet device in machine-readable form.
struct JsonDevice: Encodable {
    let id: String
    let name: String

    init(_ device: AranetDevice) {
        self.id = device.id.uuidString
        self.name = device.name
    }
}
