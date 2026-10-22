//
// SensorClient.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// The operations consumers use to talk to Aranet sensors, so they can substitute a fake for ``AranetClient``.
@MainActor
public protocol SensorClient: AnyObject {
    /// Echoes diagnostics to standard output when true.
    var verbose: Bool { get set }

    /// Scans for nearby Aranet devices for `timeout` seconds.
    func scan(timeout: TimeInterval) async throws -> [AranetDevice]

    /// Reads the current measurements from one device.
    func readCurrentReadings(from device: AranetDevice) async throws -> AranetReading

    /// Monitors one device; the stream finishes on the first failed read, and cancelling the iterating task stops the loop.
    func monitor(from device: AranetDevice) -> AsyncStream<Result<AranetReading, any Error>>
}
