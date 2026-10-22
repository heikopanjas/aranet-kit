//
// Array+DeviceMatching.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit

extension Array where Element == AranetDevice {
    /// Matches device queries against discovered devices by exact identifier or case-insensitive name fragment.
    ///
    /// A fragment shared by several devices selects the first one in discovery order.
    func match(queries: [String]) -> DeviceMatch {
        var matched: [AranetDevice] = []
        var notFound: [String] = []

        for query in queries {
            let lowercasedQuery = query.lowercased()
            let found = self.first { device in
                return device.id.uuidString.lowercased() == lowercasedQuery || device.name.lowercased().contains(lowercasedQuery)
            }

            guard let found else {
                notFound.append(query)
                continue
            }
            if matched.contains(where: { $0.id == found.id }) == false {
                matched.append(found)
            }
        }

        return DeviceMatch(matched: matched, notFound: notFound)
    }
}
