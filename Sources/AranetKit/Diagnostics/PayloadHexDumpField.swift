//
// PayloadHexDumpField.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

/// One labeled byte range in a hex dump.
struct PayloadHexDumpField: Sendable {
    let range: ClosedRange<Int>
    let description: String

    init(_ range: ClosedRange<Int>, _ description: String) {
        self.range = range
        self.description = description
    }
}
