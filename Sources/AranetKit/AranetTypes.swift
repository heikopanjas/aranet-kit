//
// AranetTypes.swift
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

// MARK: - Device Types

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

// MARK: - Status Colors

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
}

// MARK: - Status Alerts

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

// MARK: - Current Reading

/// A complete sensor reading from an Aranet device containing all available measurements and metadata.
///
/// Different Aranet devices provide different sets of measurements. Optional properties indicate
/// device-specific sensors that may not be present on all models.
public struct AranetReading: Sendable {
    /// The type of Aranet device that provided this reading.
    public let deviceType: AranetDeviceType

    /// The device's Bluetooth advertised name.
    public let name: String

    /// The firmware version string of the device.
    public let version: String

    // MARK: - Aranet2, Aranet4

    /// Ambient temperature measurement.
    ///
    /// The measurement is stored in the device's native unit (Celsius).
    /// Use `.converted(to:)` to convert to other temperature units.
    ///
    /// Available on: Aranet2, Aranet4, Aranet Radon Plus
    public let temperature: Measurement<UnitTemperature>?

    /// Relative humidity measurement as a percentage (%).
    ///
    /// Range: 0-100%
    /// Available on: Aranet2, Aranet4, Aranet Radon Plus
    public let humidity: UInt8?

    // MARK: - Aranet4

    /// Carbon dioxide concentration in parts per million (ppm).
    ///
    /// Typical indoor levels: 400-1000 ppm
    /// Available on: Aranet4 only
    public let co2: UInt16?

    /// Atmospheric pressure measurement.
    ///
    /// The measurement is stored in hectopascals (hPa).
    /// Use `.converted(to:)` to convert to other pressure units.
    ///
    /// Standard sea level pressure: ~1013 hPa
    /// Available on: Aranet4, Aranet Radon Plus
    public let pressure: Measurement<UnitPressure>?

    // MARK: - Aranet Radiation

    /// Current radiation dose rate measurement.
    ///
    /// The measurement is stored in nanosieverts per hour (nSv/h).
    /// Use `.converted(to: .microsieverts)` for µSv/h display.
    ///
    /// Typical background radiation: 50-200 nSv/h (0.05-0.2 µSv/h)
    /// Available on: Aranet Radiation only
    public let radiationRate: Measurement<UnitRadiationDose>?

    /// Cumulative radiation dose measurement.
    ///
    /// The measurement is stored in nanosieverts (nSv).
    /// Total accumulated dose since the last counter reset.
    ///
    /// Available on: Aranet Radiation only
    public let radiationTotal: Measurement<UnitRadiationDose>?

    /// Duration of radiation measurement period in seconds.
    ///
    /// Time span over which the total dose was accumulated.
    /// Available on: Aranet Radiation only
    public let radiationDuration: UInt64?

    // MARK: - Aranet Radon

    /// Radon gas concentration measurement.
    ///
    /// The measurement is stored in becquerels per cubic meter (Bq/m³).
    /// Use `.converted(to: .picocuriesPerLiter)` for pCi/L display.
    ///
    /// WHO recommended action level: 100 Bq/m³
    /// EPA recommended action level: 148 Bq/m³ (4 pCi/L)
    /// Available on: Aranet Radon Plus only
    public let radonConcentration: Measurement<UnitRadioactivity>?

    // MARK: - Common

    /// Battery charge level as a percentage (%).
    ///
    /// Range: 0-100%
    /// Available on: All devices
    public let battery: UInt8

    /// Current status indicator color displayed on the device.
    ///
    /// Reflects the device's assessment of measurement quality based on configured thresholds.
    /// Available on: Aranet4, Aranet Radon Plus
    public let status: AranetStatusColor?

    /// Measurement interval in seconds.
    ///
    /// Time between automatic sensor readings.
    /// Available on: All devices
    public let interval: UInt16?

    /// Time elapsed since last measurement in seconds.
    ///
    /// Indicates freshness of the reading data.
    /// Available on: All devices
    public let ago: UInt16?

    /// Creates a new Aranet sensor reading.
    ///
    /// - Parameters:
    ///   - deviceType: Type of Aranet device
    ///   - name: Device Bluetooth name
    ///   - version: Firmware version string
    ///   - temperature: Ambient temperature measurement
    ///   - humidity: Relative humidity in %
    ///   - co2: CO2 concentration in ppm (Aranet4)
    ///   - pressure: Atmospheric pressure measurement
    ///   - radiationRate: Dose rate measurement (Aranet Radiation)
    ///   - radiationTotal: Cumulative dose measurement (Aranet Radiation)
    ///   - radiationDuration: Measurement duration in seconds (Aranet Radiation)
    ///   - radonConcentration: Radon concentration measurement (Aranet Radon Plus)
    ///   - battery: Battery level in %
    ///   - status: Status indicator color
    ///   - interval: Measurement interval in seconds
    ///   - ago: Time since last measurement in seconds
    public init(
        deviceType: AranetDeviceType = .unknown,
        name: String = "",
        version: String = "",
        temperature: Measurement<UnitTemperature>? = nil,
        humidity: UInt8? = nil,
        co2: UInt16? = nil,
        pressure: Measurement<UnitPressure>? = nil,
        radiationRate: Measurement<UnitRadiationDose>? = nil,
        radiationTotal: Measurement<UnitRadiationDose>? = nil,
        radiationDuration: UInt64? = nil,
        radonConcentration: Measurement<UnitRadioactivity>? = nil,
        battery: UInt8 = 0,
        status: AranetStatusColor? = nil,
        interval: UInt16? = nil,
        ago: UInt16? = nil
    ) {
        self.deviceType = deviceType
        self.name = name
        self.version = version
        self.temperature = temperature
        self.humidity = humidity
        self.co2 = co2
        self.pressure = pressure
        self.radiationRate = radiationRate
        self.radiationTotal = radiationTotal
        self.radiationDuration = radiationDuration
        self.radonConcentration = radonConcentration
        self.battery = battery
        self.status = status
        self.interval = interval
        self.ago = ago
    }
}
