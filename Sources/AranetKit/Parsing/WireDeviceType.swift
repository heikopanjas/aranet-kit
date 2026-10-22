//
// WireDeviceType.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

/// Device type byte at offset 0 of F0CD1504 and F0CD3003 payloads.
///
/// These on-wire values are unrelated to the raw values of ``AranetDeviceType``;
/// never convert between the two with `init(rawValue:)`.
enum WireDeviceType: UInt8 {
    case aranet2 = 2
    case radonPlus = 3
    case radiation = 4
}
