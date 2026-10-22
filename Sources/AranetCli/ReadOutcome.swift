//
// ReadOutcome.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit

/// The result of reading one device.
struct ReadOutcome: Sendable {
    let device: AranetDevice
    let result: Result<AranetReading, any Error>
}
