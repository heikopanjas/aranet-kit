//
// AranetPayloadParser.swift
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

import CoreBluetooth
import Foundation

/// Decodes the byte layouts documented in the "Aranet Device Data Formats" section of AGENTS.md.
///
/// The parser is pure: it depends only on the payload and the characteristic it was read from,
/// so every layout can be verified without Bluetooth hardware.
enum AranetPayloadParser {
    /// Payload sizes per characteristic, in bytes.
    enum PayloadLength {
        /// F0CD1503: CO2, temperature, pressure, humidity, battery, status.
        static let aranet4Basic = 9
        /// F0CD3001: the basic layout followed by interval and ago.
        static let aranet4Detailed = 13
        /// F0CD1504 with device type 0x02: device type, interval, ago, battery, temperature, humidity, status.
        static let aranet2 = 10
        /// F0CD1504 with device type 0x04: rate stored as nSv/h times ten.
        static let radiationPaired = 28
        /// F0CD3003 with device type 0x04: rate stored as nSv/h, followed by 20 extended bytes.
        static let radiationDetailed = 48
    }

    /// Temperature is transmitted in 0.05 degree Celsius units.
    static let temperatureScale = 20.0
    /// Pressure is transmitted in 0.1 hPa units.
    static let pressureScale = 10.0
    /// The paired radiation characteristic transmits the dose rate multiplied by ten.
    static let pairedRadiationRateScale = 10.0
    /// Offset of the interval field in radiation payloads; byte 1 is undocumented and skipped.
    static let radiationFieldsOffset = 2

    /// Parses a reading characteristic payload.
    ///
    /// - Parameters:
    ///   - data: Raw characteristic value.
    ///   - characteristic: Characteristic the value was read from; `nil` and the Aranet4 characteristics use the Aranet4 layout.
    ///   - name: Device name to store on the reading.
    ///   - version: Firmware version to store on the reading.
    /// - Returns: The decoded reading.
    /// - Throws: ``AranetError/invalidData`` when the payload is shorter than its layout or names an unsupported device type.
    static func reading(from data: Data, characteristic: CBUUID?, name: String, version: String) throws -> AranetReading {
        if Self.usesTypedLayout(characteristic) == true {
            return try Self.typedReading(from: data, name: name, version: version)
        }
        return try Self.aranet4Reading(from: data, name: name, version: version)
    }

    /// Hex-dump lines for the verbose log, or an empty array when no field table applies.
    static func hexDumpLines(for data: Data, characteristic: CBUUID?) -> [String] {
        if Self.usesTypedLayout(characteristic) == false {
            return PayloadHexDump.lines(for: data, title: "Aranet4", fields: PayloadHexDump.aranet4Fields)
        }

        guard let typeByte = data.first, WireDeviceType(rawValue: typeByte) == .radiation else {
            return []
        }
        return PayloadHexDump.lines(for: data, title: "Aranet Radiation", fields: PayloadHexDump.radiationFields)
    }

    // MARK: - Private

    private static func usesTypedLayout(_ characteristic: CBUUID?) -> Bool {
        return characteristic == AranetUUID.characteristicCurrentReadingsAR2
            || characteristic == AranetUUID.characteristicCurrentReadingsAR2Detailed
    }

    private static func typedReading(from data: Data, name: String, version: String) throws -> AranetReading {
        var reader = ByteReader(data)
        let typeByte = try reader.uint8()

        guard let wireType = WireDeviceType(rawValue: typeByte) else {
            throw AranetError.invalidData
        }

        switch wireType {
            case .radiation:
                return try Self.radiationReading(from: data, name: name, version: version)
            case .aranet2:
                return try Self.aranet2Reading(from: data, name: name, version: version)
            case .radonPlus:
                // The Radon Plus layout is undocumented; see AGENTS.md before implementing it.
                throw AranetError.invalidData
        }
    }

    private static func radiationReading(from data: Data, name: String, version: String) throws -> AranetReading {
        let rateDivisor: Double
        if data.count == PayloadLength.radiationPaired {
            rateDivisor = Self.pairedRadiationRateScale
        }
        else if data.count >= PayloadLength.radiationDetailed {
            rateDivisor = 1
        }
        else {
            throw AranetError.invalidData
        }

        var reader = ByteReader(data, offset: Self.radiationFieldsOffset)
        let interval = try reader.uint16LE()
        let ago = try reader.uint16LE()
        let battery = try reader.uint8()
        let rateRaw = try reader.uint32LE()
        let totalRaw = try reader.uint64LE()
        let duration = try reader.uint64LE()
        let statusByte = try reader.uint8()

        return AranetReading(
            deviceType: .aranetRadiation,
            name: name,
            version: version,
            radiationRate: Measurement(value: Double(rateRaw) / rateDivisor, unit: UnitRadiationDose.nanosieverts),
            radiationTotal: Measurement(value: Double(totalRaw), unit: UnitRadiationDose.nanosieverts),
            radiationDuration: duration,
            battery: battery,
            status: AranetStatusColor.fromRadiationByte(statusByte),
            interval: interval,
            ago: ago
        )
    }

    private static func aranet2Reading(from data: Data, name: String, version: String) throws -> AranetReading {
        guard data.count >= PayloadLength.aranet2 else {
            throw AranetError.invalidData
        }

        var reader = ByteReader(data, offset: 1)
        let interval = try reader.uint16LE()
        let ago = try reader.uint16LE()
        let battery = try reader.uint8()
        let temperatureRaw = try reader.uint16LE()
        let humidity = try reader.uint8()
        // The status byte carries humidity and temperature alert bits that AranetReading does not model yet.
        try reader.skip(1)

        return AranetReading(
            deviceType: .aranet2,
            name: name,
            version: version,
            temperature: Measurement(value: Double(temperatureRaw) / Self.temperatureScale, unit: UnitTemperature.celsius),
            humidity: humidity,
            battery: battery,
            interval: interval,
            ago: ago
        )
    }

    private static func aranet4Reading(from data: Data, name: String, version: String) throws -> AranetReading {
        guard data.count >= PayloadLength.aranet4Basic else {
            throw AranetError.invalidData
        }

        var reader = ByteReader(data)
        let co2 = try reader.uint16LE()
        let temperatureRaw = try reader.uint16LE()
        let pressureRaw = try reader.uint16LE()
        let humidity = try reader.uint8()
        let battery = try reader.uint8()
        let statusRaw = try reader.uint8()

        var interval: UInt16?
        var ago: UInt16?
        if data.count >= PayloadLength.aranet4Detailed {
            interval = try reader.uint16LE()
            ago = try reader.uint16LE()
        }

        return AranetReading(
            deviceType: .aranet4,
            name: name,
            version: version,
            temperature: Measurement(value: Double(temperatureRaw) / Self.temperatureScale, unit: UnitTemperature.celsius),
            humidity: humidity,
            co2: co2,
            pressure: Measurement(value: Double(pressureRaw) / Self.pressureScale, unit: UnitPressure.hectopascals),
            battery: battery,
            status: AranetStatusColor(rawValue: statusRaw),
            interval: interval,
            ago: ago
        )
    }
}
