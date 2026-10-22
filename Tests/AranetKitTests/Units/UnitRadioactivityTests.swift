import AranetKit
import Foundation
import Testing

struct RadioactivityConversionCase: Sendable, CustomTestStringConvertible {
    let value: Double
    let unit: UnitRadioactivity
    let expected: Double
    let target: UnitRadioactivity

    var testDescription: String {
        return "\(self.value) \(self.unit.symbol) is \(self.expected) \(self.target.symbol)"
    }
}

@Suite(.tags(.units))
struct UnitRadioactivityTests {
    private static let conversions: [RadioactivityConversionCase] = [
        RadioactivityConversionCase(value: 37, unit: .becquerelsPerCubicMeter, expected: 1, target: .picocuriesPerLiter),
        RadioactivityConversionCase(value: 1, unit: .picocuriesPerLiter, expected: 37, target: .becquerelsPerCubicMeter),
        RadioactivityConversionCase(value: 148, unit: .becquerelsPerCubicMeter, expected: 4, target: .picocuriesPerLiter),
        RadioactivityConversionCase(value: 4, unit: .picocuriesPerLiter, expected: 148, target: .becquerelsPerCubicMeter),
        RadioactivityConversionCase(value: 100, unit: .becquerelsPerCubicMeter, expected: 100, target: .becquerelsPerCubicMeter),
        RadioactivityConversionCase(value: 0, unit: .picocuriesPerLiter, expected: 0, target: .becquerelsPerCubicMeter)
    ]

    @Test("Base unit is becquerels per cubic meter")
    func baseUnitIsBecquerelsPerCubicMeter() -> Void {
        #expect(UnitRadioactivity.baseUnit() === UnitRadioactivity.becquerelsPerCubicMeter)
    }

    @Test("Symbols are the conventional ones")
    func symbolsAreConventional() -> Void {
        #expect(UnitRadioactivity.becquerelsPerCubicMeter.symbol == "Bq/m\u{00B3}")
        #expect(UnitRadioactivity.picocuriesPerLiter.symbol == "pCi/L")
    }

    @Test("Converts between Bq/m3 and pCi/L", arguments: UnitRadioactivityTests.conversions)
    func convertsBetweenUnits(_ conversion: RadioactivityConversionCase) -> Void {
        let measurement = Measurement(value: conversion.value, unit: conversion.unit)
        let converted = measurement.converted(to: conversion.target)

        #expect(isApproximately(converted.value, conversion.expected, tolerance: 1e-9), "Converted value was \(converted.value)")
        #expect(converted.unit === conversion.target)
    }

    @Test("Custom units can be created with a symbol and converter")
    func customUnitInitializer() -> Void {
        let kilobecquerels = UnitRadioactivity(symbol: "kBq/m\u{00B3}", converter: UnitConverterLinear(coefficient: 1_000))
        let converted = Measurement(value: 2, unit: kilobecquerels).converted(to: .becquerelsPerCubicMeter)

        #expect(kilobecquerels.symbol == "kBq/m\u{00B3}")
        #expect(isApproximately(converted.value, 2_000))
    }

    @Test("Units survive secure coding round trips")
    func secureCodingRoundTrip() throws -> Void {
        let data = try NSKeyedArchiver.archivedData(withRootObject: UnitRadioactivity.picocuriesPerLiter, requiringSecureCoding: true)
        let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: UnitRadioactivity.self, from: data)
        let unit = try #require(decoded)

        #expect(unit.symbol == "pCi/L")
        #expect(isApproximately(Measurement(value: 1, unit: unit).converted(to: .becquerelsPerCubicMeter).value, 37))
    }
}
