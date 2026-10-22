//
// MonitorSchedule.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Computes how long to wait before reading a device again.
enum MonitorSchedule {
    /// Seconds added after the device's expected update so the new sample is ready to be read.
    static let readMargin: TimeInterval = 3

    /// Shortest wait between two reads.
    ///
    /// A device that reports `ago` larger than its `interval` is overdue; it is re-read after this
    /// delay instead of continuously, which would keep the Bluetooth connection busy.
    static let minimumDelay: TimeInterval = 5

    /// Delay until the next read: time until the device's next update plus ``readMargin``, never below ``minimumDelay``.
    ///
    /// - Parameters:
    ///   - interval: The device's measurement interval in seconds.
    ///   - ago: Seconds since the device's last measurement, or `nil` when the payload did not include it.
    /// - Returns: The delay in seconds.
    static func nextDelay(interval: TimeInterval, ago: UInt16?) -> TimeInterval {
        guard let ago else {
            return max(interval + Self.readMargin, Self.minimumDelay)
        }

        let timeUntilNextUpdate = interval - TimeInterval(ago)
        return max(timeUntilNextUpdate + Self.readMargin, Self.minimumDelay)
    }
}
