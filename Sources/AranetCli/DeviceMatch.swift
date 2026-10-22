//
// DeviceMatch.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit

/// The outcome of matching user queries against discovered devices.
struct DeviceMatch: Equatable {
    /// Devices that matched at least one query, in query order, without duplicates.
    let matched: [AranetDevice]
    /// Queries that matched no device.
    let notFound: [String]
}
