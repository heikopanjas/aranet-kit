//
// ReadCommand.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth
import Foundation

/// What ``ReadSession`` asks the client to do next.
enum ReadCommand {
    case discoverServices
    case discoverCharacteristics(service: CBUUID)
    case read(service: CBUUID, characteristic: CBUUID)
    case complete(data: Data, name: String, version: String)
    case fail(any Error)
}
