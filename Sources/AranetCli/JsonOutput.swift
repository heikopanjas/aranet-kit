//
// JsonOutput.swift
// AranetCli
//
// Machine-readable output for script and agent usage (--json).
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit
import Foundation

// MARK: - Payloads

/// A discovered Aranet device in machine-readable form.
struct JsonDevice: Encodable {
    let id: String
    let name: String

    init(_ device: AranetDevice) {
        id = device.id.uuidString
        name = device.name
    }
}

/// A single measurement with its unit.
struct JsonMeasurement<Value: Encodable>: Encodable {
    let value: Value
    let unit: String
}

/// A sensor reading in machine-readable form.
///
/// Every measurement is emitted as a `value`/`unit` pair. Measurements the
/// device does not provide are omitted entirely.
struct JsonReading: Encodable {
    let device: String
    let deviceType: String
    let firmwareVersion: String?
    let battery: JsonMeasurement<UInt8>
    let status: String?
    let timestamp: Date
    let interval: JsonMeasurement<UInt16>?
    let age: JsonMeasurement<UInt16>?
    let humidity: JsonMeasurement<UInt8>?
    let pressure: JsonMeasurement<Double>?
    let temperature: JsonMeasurement<Double>?
    let co2: JsonMeasurement<UInt16>?
    let radonConcentration: JsonMeasurement<Double>?
    let radiationDuration: JsonMeasurement<UInt64>?
    let radiationRate: JsonMeasurement<Double>?
    let radiationTotal: JsonMeasurement<Double>?

    init(_ reading: AranetReading, timestamp: Date = Date()) {
        device = reading.name
        deviceType = reading.deviceType.name
        firmwareVersion = reading.version.isEmpty ? nil : reading.version
        battery = JsonMeasurement(value: reading.battery, unit: "percent")
        status = reading.status?.name
        self.timestamp = timestamp
        interval = reading.interval.map { JsonMeasurement(value: $0, unit: "seconds") }
        age = reading.ago.map { JsonMeasurement(value: $0, unit: "seconds") }
        humidity = reading.humidity.map { JsonMeasurement(value: $0, unit: "percent") }
        pressure = reading.pressure.map { JsonMeasurement(value: $0.value, unit: "hPa") }
        temperature = reading.temperature.map { JsonMeasurement(value: $0.value, unit: "C") }
        co2 = reading.co2.map { JsonMeasurement(value: $0, unit: "ppm") }
        radonConcentration = reading.radonConcentration.map {
            JsonMeasurement(value: $0.value, unit: "Bq/m³")
        }
        radiationDuration = reading.radiationDuration.map {
            JsonMeasurement(value: $0, unit: "seconds")
        }
        radiationRate = reading.radiationRate.map {
            JsonMeasurement(value: $0.converted(to: .microsieverts).value, unit: "µSv/h")
        }
        radiationTotal = reading.radiationTotal.map {
            JsonMeasurement(value: $0.converted(to: .microsieverts).value, unit: "µSv")
        }
    }
}

/// An error in machine-readable form, written to standard output in JSON mode.
struct JsonError: Encodable {
    let error: String
    let device: String?
}

// MARK: - Emitting

/// Encodes payloads as JSON on standard output, including errors.
enum JsonOutput {
    private static func encoder(pretty: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting =
            pretty == true
            ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func text<T: Encodable>(for value: T, pretty: Bool) -> String? {
        guard let data = try? encoder(pretty: pretty).encode(value) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Writes a JSON payload to standard output.
    ///
    /// - Parameters:
    ///   - value: The payload to encode.
    ///   - pretty: Pass `false` for single-line output, as required by the
    ///     newline-delimited stream of the `monitor` command.
    static func emit<T: Encodable>(_ value: T, pretty: Bool = true) {
        guard let text = text(for: value, pretty: pretty) else {
            return
        }

        print(text)
    }

    /// Writes a JSON error payload to standard output as a single line.
    ///
    /// JSON mode keeps every output stream machine-readable, so errors are written
    /// to stdout alongside the data instead of stderr.
    static func emitError(_ message: String, device: String? = nil) {
        guard let text = text(for: JsonError(error: message, device: device), pretty: false) else {
            return
        }

        print(text)
    }

    /// Writes a JSON error payload derived from an ``AranetError`` or generic error.
    static func emitError(_ error: Error, device: String? = nil) {
        if let aranetError = error as? AranetError {
            emitError(aranetError.description, device: device)
        }
        else {
            emitError(error.localizedDescription, device: device)
        }
    }
}
