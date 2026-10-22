//
// PayloadHexDump.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Formats reading payloads as annotated hex dumps for verbose diagnostics.
enum PayloadHexDump {
    static let aranet4Fields: [PayloadHexDumpField] = [
        PayloadHexDumpField(0 ... 1, "CO2 (UInt16 LE, ppm)"),
        PayloadHexDumpField(2 ... 3, "Temperature (UInt16 LE, raw/20)"),
        PayloadHexDumpField(4 ... 5, "Pressure (UInt16 LE, raw/10 hPa)"),
        PayloadHexDumpField(6 ... 6, "Humidity (UInt8, %)"),
        PayloadHexDumpField(7 ... 7, "Battery (UInt8, %)"),
        PayloadHexDumpField(8 ... 8, "Status (0=Err, 1=G, 2=Y, 3=R)"),
        PayloadHexDumpField(9 ... 10, "Interval (UInt16 LE, sec)"),
        PayloadHexDumpField(11 ... 12, "Ago (UInt16 LE, sec)")
    ]

    static let radiationFields: [PayloadHexDumpField] = [
        PayloadHexDumpField(0 ... 1, "Device type + H"),
        PayloadHexDumpField(2 ... 3, "Interval (UInt16 LE, sec)"),
        PayloadHexDumpField(4 ... 5, "Ago (UInt16 LE, sec)"),
        PayloadHexDumpField(6 ... 6, "Battery (UInt8, %)"),
        PayloadHexDumpField(7 ... 10, "Rate (UInt32 LE, nSv/h)"),
        PayloadHexDumpField(11 ... 18, "Total (UInt64 LE, nSv)"),
        PayloadHexDumpField(19 ... 26, "Duration (UInt64 LE, sec)"),
        PayloadHexDumpField(27 ... 27, "Status (0x05=G, 0x0A=Y, 0x0B=R)"),
        PayloadHexDumpField(28 ... 35, "Total dose (UInt64 LE, uSv)"),
        PayloadHexDumpField(36 ... 43, "Realtime duration (UInt64 LE, sec, 60s granularity)"),
        PayloadHexDumpField(44 ... 47, "Reserved (zero)")
    ]

    private static let rangeColumnWidth = 5
    private static let valueColumnWidth = 36

    /// Returns one header line, one line per field that starts inside `data`, and one footer line.
    ///
    /// Fields that start past the end of the payload are omitted; fields that end past it are clamped.
    static func lines(for data: Data, title: String, fields: [PayloadHexDumpField]) -> [String] {
        var lines = ["=== \(title) (\(data.count) bytes) ==="]
        let bytes = [UInt8](data)

        for field in fields where field.range.lowerBound < bytes.count {
            let end = min(field.range.upperBound, bytes.count - 1)
            let slice = bytes[field.range.lowerBound ... end]
            let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")

            var littleEndianValue: UInt64 = 0
            for (index, byte) in slice.enumerated() {
                littleEndianValue |= UInt64(byte) << (index * 8)
            }

            let rangeText = Self.rangeText(for: field.range).padding(toLength: Self.rangeColumnWidth, withPad: " ", startingAt: 0)
            let valueText = "\(hex) = \(littleEndianValue)".padding(toLength: Self.valueColumnWidth, withPad: " ", startingAt: 0)
            lines.append("\(rangeText)  \(valueText) \(field.description)")
        }

        lines.append("===")
        return lines
    }

    private static func rangeText(for range: ClosedRange<Int>) -> String {
        if range.lowerBound == range.upperBound {
            return "\(range.lowerBound)"
        }
        return "\(range.lowerBound)-\(range.upperBound)"
    }
}
