//
// AranetNotifications.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

extension Notification.Name {
    /// Posted when ``AranetClient/monitor(from:)`` delivers a new reading.
    public static let aranetReadingDidUpdate = Notification.Name("AranetKit.readingDidUpdate")
}

/// Keys for ``Notification.Name/aranetReadingDidUpdate`` user info.
public enum AranetNotificationKey {
    public static let device = "AranetKit.device"
    public static let reading = "AranetKit.reading"
    public static let receivedAt = "AranetKit.receivedAt"
}

enum AranetNotifications {
    static func postReadingDidUpdate(device: AranetDevice, reading: AranetReading) {
        NotificationCenter.default.post(
            name: .aranetReadingDidUpdate,
            object: nil,
            userInfo: [
                AranetNotificationKey.device: device,
                AranetNotificationKey.reading: reading,
                AranetNotificationKey.receivedAt: Date()
            ]
        )
    }
}
