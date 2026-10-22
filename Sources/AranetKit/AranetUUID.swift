//
// AranetUUID.swift
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

@preconcurrency import CoreBluetooth
import Foundation

/// Bluetooth Low Energy service and characteristic UUIDs used by Aranet devices.
///
/// This namespace contains all the standard and vendor-specific UUIDs required for
/// communicating with Aranet sensors via Bluetooth LE. The UUIDs are organized by
/// service type (GAP, DIS, SAF Tehnika) and their respective characteristics.
public enum AranetUUID {
    // MARK: GAP Service

    /// Generic Access Profile (GAP) service UUID.
    public static let serviceGAP = CBUUID(string: "1800")

    /// Device name characteristic (GAP service).
    public static let characteristicDeviceName = CBUUID(string: "2A00")

    // MARK: Device Information Service

    /// Device Information Service (DIS) UUID.
    public static let serviceDIS = CBUUID(string: "180A")

    /// Software/firmware revision string characteristic.
    public static let characteristicSoftwareRevision = CBUUID(string: "2A26")

    /// Serial number string characteristic.
    public static let characteristicSerialNumber = CBUUID(string: "2A25")

    // MARK: SAF Tehnika Service (Aranet)

    /// Primary SAF Tehnika service UUID (Aranet-specific).
    public static let serviceSAFTehnika = CBUUID(string: "FCE0")

    /// Legacy SAF Tehnika service UUID (older firmware versions).
    public static let serviceSAFTehnikaOld = CBUUID(string: "F0CD1400-95DA-4F4B-9AC8-AA55D312AF0C")

    // MARK: SAF Tehnika Characteristics

    /// Basic current readings characteristic (requires pairing/authentication).
    public static let characteristicCurrentReadings = CBUUID(
        string: "F0CD1503-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Detailed current readings characteristic (no pairing required, preferred).
    public static let characteristicCurrentReadingsDetailed = CBUUID(
        string: "F0CD3001-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Aranet2 current readings characteristic.
    public static let characteristicCurrentReadingsAR2 = CBUUID(
        string: "F0CD1504-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Aranet2/Radiation detailed current readings characteristic (no pairing required).
    public static let characteristicCurrentReadingsAR2Detailed = CBUUID(
        string: "F0CD3003-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Measurement interval characteristic (time between sensor updates).
    public static let characteristicInterval = CBUUID(string: "F0CD2002-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Seconds since last update characteristic (sensor data age).
    public static let characteristicSecondsSinceUpdate = CBUUID(
        string: "F0CD2004-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Total number of stored readings characteristic (history size).
    public static let characteristicTotalReadings = CBUUID(
        string: "F0CD2001-95DA-4F4B-9AC8-AA55D312AF0C")

    /// Priority-ordered list of reading characteristics to try.
    /// Detailed variants (no pairing required) are preferred over basic ones.
    public static let readingCharacteristicPriority: [CBUUID] = [
        Self.characteristicCurrentReadingsDetailed,
        Self.characteristicCurrentReadingsAR2Detailed,
        Self.characteristicCurrentReadingsAR2,
        Self.characteristicCurrentReadings
    ]

    /// Set of all characteristic UUIDs that provide sensor reading data.
    public static let readingCharacteristics: Set<CBUUID> = Set(Self.readingCharacteristicPriority)
}
