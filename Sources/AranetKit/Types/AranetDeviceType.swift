//
// AranetDeviceType.swift
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

public enum AranetDeviceType: UInt8, Sendable {
    case aranet4 = 0
    case aranet2 = 1
    case aranetRadiation = 2
    case aranetRadon = 3
    case unknown = 255

    public var name: String {
        switch self {
            case .aranet4:
                return "Aranet4"
            case .aranet2:
                return "Aranet2"
            case .aranetRadiation:
                return "Aranet Radiation"
            case .aranetRadon:
                return "Aranet Radon Plus"
            case .unknown:
                return "Unknown Aranet Device"
        }
    }
}
