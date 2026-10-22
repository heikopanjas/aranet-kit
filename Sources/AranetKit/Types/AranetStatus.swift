//
// AranetStatus.swift
// AranetKit
//
// Swift reimplementation of the Python aranet4 library
// Based on https://github.com/Anrijs/Aranet4-Python
//
// Copyright (c) 2022 Anrijs Jargans (original Python implementation)
// Copyright (c) 2025 Heiko Panjas (Swift reimplementation)
//
// SPDX-License-Identifier: MIT
//

import Foundation

public enum AranetStatus: UInt8, Sendable {
    case off = 0
    case under = 1
    case over = 2
    case dash = 3

    public var name: String {
        switch self {
            case .off:
                return "OFF"
            case .under:
                return "UNDER"
            case .over:
                return "OVER"
            case .dash:
                return "DASH"
        }
    }
}
