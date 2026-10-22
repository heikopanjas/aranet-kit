//
// AranetStatusColor.swift
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

public enum AranetStatusColor: UInt8, Sendable {
    case error = 0
    case green = 1
    case yellow = 2
    case red = 3

    public var name: String {
        switch self {
            case .error:
                return "ERROR"
            case .green:
                return "GREEN"
            case .yellow:
                return "YELLOW"
            case .red:
                return "RED"
        }
    }

    /// Maps Aranet Radiation status byte to a status color.
    ///
    /// Aranet Radiation uses a different encoding than Aranet4:
    /// 0x05 = Green, 0x0A = Yellow, 0x0B = Red.
    public static func fromRadiationByte(_ byte: UInt8) -> AranetStatusColor? {
        switch byte {
            case 0x05: return .green
            case 0x0A: return .yellow
            case 0x0B: return .red
            default: return nil
        }
    }
}
