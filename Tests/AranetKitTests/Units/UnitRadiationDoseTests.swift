import AranetKit
import Foundation
import Testing

struct DoseConversionCase: Sendable, CustomTestStringConvertible {
    let value: Double
    let unit: UnitRadiationDose
    let expected: Double
    let target: UnitRadiationDose

    var testDescription: String {
        return "\(self.value) \(self.unit.symbol) is \(self.expected) \(self.target.symbol)"
    }
}

@Suite(.tags(.units))
struct UnitRadiationDoseTests {
    private static let conversions: [DoseConversionCase] = [
        DoseConversionCase(value: 1_000, unit: .nanosieverts, expected: 1, target: .microsieverts),
        DoseConversionCase(value: 1, unit: .microsieverts, expected: 1_000, target: .nanosieverts),
        DoseConversionCase(value: 1_000_000, unit: .nanosieverts, expected: 1, target: .millisieverts),
        DoseConversionCase(value: 1.5, unit: .millisieverts, expected: 1_500, target: .microsieverts),
        DoseConversionCase(value: 1, unit: .sieverts, expected: 1_000_000_000, target: .nanosieverts),
        DoseConversionCase(value: 2_500, unit: .millisieverts, expected: 2.5, target: .sieverts),
        DoseConversionCase(value: 0, unit: .sieverts, expected: 0, target: .nanosieverts),
        DoseConversionCase(value: 120, unit: .nanosieverts, expected: 0.12, target: .microsieverts)
    ]

    @Test("Base unit is nanosieverts")
    func baseUnitIsNanosieverts() -> Void {
        #expect(UnitRadiationDose.baseUnit() === UnitRadiationDose.nanosieverts)
    }

    @Test("Symbols match the SI prefixes")
    func symbolsMatchPrefixes() -> Void {
        #expect(UnitRadiationDose.nanosieverts.symbol == "nSv")
        #expect(UnitRadiationDose.microsieverts.symbol == "\u{00B5}Sv")
        #expect(UnitRadiationDose.millisieverts.symbol == "mSv")
        #expect(UnitRadiationDose.sieverts.symbol == "Sv")
    }

    @Test("Converts between magnitudes", arguments: UnitRadiationDoseTests.conversions)
    func convertsBetweenMagnitudes(_ conversion: DoseConversionCase) -> Void {
        let measurement = Measurement(value: conversion.value, unit: conversion.unit)
        let converted = measurement.converted(to: conversion.target)

        #expect(isApproximately(converted.value, conversion.expected), "Converted value was \(converted.value)")
        #expect(converted.unit === conversion.target)
    }

    @Test("Measurements compare equal across units")
    func measurementsCompareAcrossUnits() -> Void {
        let nanosieverts = Measurement(value: 2_000, unit: UnitRadiationDose.nanosieverts)
        let microsieverts = Measurement(value: 2, unit: UnitRadiationDose.microsieverts)

        #expect(nanosieverts == microsieverts)
        #expect(nanosieverts < Measurement(value: 3, unit: UnitRadiationDose.microsieverts))
    }

    @Test("Custom units can be created with a symbol and converter")
    func customUnitInitializer() -> Void {
        let kilosieverts = UnitRadiationDose(symbol: "kSv", converter: UnitConverterLinear(coefficient: 1_000_000_000_000))
        let converted = Measurement(value: 1, unit: kilosieverts).converted(to: .sieverts)

        #expect(kilosieverts.symbol == "kSv")
        #expect(isApproximately(converted.value, 1_000))
    }

    @Test("Units survive secure coding round trips")
    func secureCodingRoundTrip() throws -> Void {
        let data = try NSKeyedArchiver.archivedData(withRootObject: UnitRadiationDose.millisieverts, requiringSecureCoding: true)
        let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: UnitRadiationDose.self, from: data)
        let unit = try #require(decoded)

        #expect(unit.symbol == "mSv")
        #expect(isApproximately(Measurement(value: 1, unit: unit).converted(to: .nanosieverts).value, 1_000_000))
    }
}
