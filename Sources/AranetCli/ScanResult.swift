//
// ScanResult.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit

/// A scan performed on behalf of `read` or `monitor`: the client that scanned and what the queries matched.
struct ScanResult {
    let client: any SensorClient
    let match: DeviceMatch
}
