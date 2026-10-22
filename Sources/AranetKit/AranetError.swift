//
// AranetError.swift
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

/// Errors that can occur during Aranet device communication.
///
/// These errors represent various failure modes when scanning for, connecting to,
/// or reading data from Aranet Bluetooth devices. Each error includes a descriptive
/// message to help diagnose and resolve issues.
public enum AranetError: Error, CustomStringConvertible, LocalizedError {
    /// Bluetooth is not available or not ready for use.
    case bluetoothUnavailable

    /// Bluetooth access has not been authorized by the user.
    case bluetoothUnauthorized

    /// Bluetooth Low Energy is not supported on this device.
    case bluetoothUnsupported

    /// The requested Aranet device could not be found during scanning.
    case deviceNotFound

    /// Failed to establish a connection to the device.
    case connectionFailed

    /// Failed to read data from a Bluetooth characteristic.
    case readFailed

    /// Received data that could not be parsed or is in an unexpected format.
    case invalidData

    /// An operation exceeded its allowed time limit.
    case timeout

    /// The device requires Bluetooth pairing before accessing encrypted characteristics.
    case pairingRequired

    /// A read of the same device is already in progress.
    case operationInProgress

    /// Human-readable description of the error with actionable guidance.
    public var description: String {
        switch self {
            case .bluetoothUnavailable:
                return "Bluetooth is unavailable or not ready"
            case .bluetoothUnauthorized:
                return "Bluetooth access is not authorized. Please grant Bluetooth permissions in System Settings."
            case .bluetoothUnsupported:
                return "Bluetooth is not supported on this device"
            case .deviceNotFound:
                return "Device not found"
            case .connectionFailed:
                return "Failed to connect to device"
            case .readFailed:
                return "Failed to read characteristic"
            case .invalidData:
                return "Invalid data received"
            case .timeout:
                return "Operation timed out"
            case .pairingRequired:
                return """
                    Device pairing required. The device will display a PIN code.

                    macOS should show a pairing dialog; enter the PIN code displayed on the Aranet device screen.

                    If no dialog appears:
                    1. Make sure the device is showing the PIN (it may time out)
                    2. Try again
                    3. The PIN is usually a 6-digit number like 122867

                    Note: The device will not appear in the System Settings Bluetooth list.
                    This is normal for BLE devices; pairing happens through the app.
                    """
            case .operationInProgress:
                return "A read of this device is already in progress"
        }
    }

    public var errorDescription: String? {
        return self.description
    }
}
