//
// JsonReading.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit
import Foundation

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
        self.device = reading.name
        self.deviceType = reading.deviceType.name
        self.firmwareVersion = reading.version.isEmpty == true ? nil : reading.version
        self.battery = JsonMeasurement(value: reading.battery, unit: "percent")
        self.status = reading.status?.name
        self.timestamp = timestamp
        self.interval = reading.interval.map { JsonMeasurement(value: $0, unit: "seconds") }
        self.age = reading.ago.map { JsonMeasurement(value: $0, unit: "seconds") }
        self.humidity = reading.humidity.map { JsonMeasurement(value: $0, unit: "percent") }
        self.pressure = reading.pressure.map { JsonMeasurement(value: $0.value, unit: "hPa") }
        self.temperature = reading.temperature.map { JsonMeasurement(value: $0.value, unit: "C") }
        self.co2 = reading.co2.map { JsonMeasurement(value: $0, unit: "ppm") }
        self.radonConcentration = reading.radonConcentration.map {
            JsonMeasurement(value: $0.value, unit: "Bq/m\u{00B3}")
        }
        self.radiationDuration = reading.radiationDuration.map {
            JsonMeasurement(value: $0, unit: "seconds")
        }
        self.radiationRate = reading.radiationRate.map {
            JsonMeasurement(value: $0.converted(to: .microsieverts).value, unit: "\u{00B5}Sv/h")
        }
        self.radiationTotal = reading.radiationTotal.map {
            JsonMeasurement(value: $0.converted(to: .microsieverts).value, unit: "\u{00B5}Sv")
        }
    }
}
