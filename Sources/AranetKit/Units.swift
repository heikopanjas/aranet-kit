//
// Units.swift
// AranetKit
//
// Custom Foundation unit types for Aranet sensor measurements.
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - Radiation Dose Units

/// A unit of measure for radiation dose.
///
/// Radiation dose is measured in sieverts (Sv), which quantifies the biological effect
/// of ionizing radiation. The base unit for `UnitRadiationDose` is nanosieverts (nSv).
///
/// Common conversions:
/// - 1 Sv = 1,000,000,000 nSv
/// - 1 mSv = 1,000,000 nSv
/// - 1 µSv = 1,000 nSv
///
/// Typical background radiation: 50-200 nSv/h (0.05-0.2 µSv/h)
public final class UnitRadiationDose: Dimension, @unchecked Sendable {

    /// Nanosieverts (nSv) - base unit.
    ///
    /// This is the base unit for radiation dose measurements in AranetKit.
    public static let nanosieverts = UnitRadiationDose(
        symbol: "nSv",
        converter: UnitConverterLinear(coefficient: 1.0)
    )

    /// Microsieverts (µSv).
    ///
    /// 1 µSv = 1,000 nSv
    public static let microsieverts = UnitRadiationDose(
        symbol: "µSv",
        converter: UnitConverterLinear(coefficient: 1000.0)
    )

    /// Millisieverts (mSv).
    ///
    /// 1 mSv = 1,000,000 nSv = 1,000 µSv
    public static let millisieverts = UnitRadiationDose(
        symbol: "mSv",
        converter: UnitConverterLinear(coefficient: 1_000_000.0)
    )

    /// Sieverts (Sv).
    ///
    /// 1 Sv = 1,000,000,000 nSv = 1,000 mSv
    public static let sieverts = UnitRadiationDose(
        symbol: "Sv",
        converter: UnitConverterLinear(coefficient: 1_000_000_000.0)
    )

    /// Returns the base unit for radiation dose (nanosieverts).
    public override class func baseUnit() -> Self {
        return nanosieverts as! Self
    }

    /// Creates a radiation dose unit with the specified symbol and converter.
    ///
    /// - Parameters:
    ///   - symbol: The unit's symbol (e.g., "nSv", "µSv")
    ///   - converter: The unit converter for this unit
    public override init(symbol: String, converter: UnitConverter) {
        super.init(symbol: symbol, converter: converter)
    }

    /// Required initializer for NSSecureCoding conformance.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Radioactivity Concentration Units

/// A unit of measure for radioactivity concentration.
///
/// Radioactivity concentration is measured for radon gas in air, expressed as
/// activity per unit volume. The base unit is becquerels per cubic meter (Bq/m³).
///
/// Common reference levels:
/// - WHO recommended action level: 100 Bq/m³
/// - EPA recommended action level: 148 Bq/m³ (4 pCi/L)
///
/// Conversion:
/// - 1 Ci = 37 GBq (exactly)
/// - 1 pCi/L ≈ 37 Bq/m³
public final class UnitRadioactivity: Dimension, @unchecked Sendable {

    /// Becquerels per cubic meter (Bq/m³) - base unit.
    ///
    /// This is the SI unit for radioactivity concentration.
    public static let becquerelsPerCubicMeter = UnitRadioactivity(
        symbol: "Bq/m³",
        converter: UnitConverterLinear(coefficient: 1.0)
    )

    /// Picocuries per liter (pCi/L).
    ///
    /// Common unit used in the United States for radon measurements.
    /// 1 pCi/L ≈ 37 Bq/m³
    public static let picocuriesPerLiter = UnitRadioactivity(
        symbol: "pCi/L",
        converter: UnitConverterLinear(coefficient: 37.0)
    )

    /// Returns the base unit for radioactivity concentration (Bq/m³).
    public override class func baseUnit() -> Self {
        return becquerelsPerCubicMeter as! Self
    }

    /// Creates a radioactivity unit with the specified symbol and converter.
    ///
    /// - Parameters:
    ///   - symbol: The unit's symbol (e.g., "Bq/m³", "pCi/L")
    ///   - converter: The unit converter for this unit
    public override init(symbol: String, converter: UnitConverter) {
        super.init(symbol: symbol, converter: converter)
    }

    /// Required initializer for NSSecureCoding conformance.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
