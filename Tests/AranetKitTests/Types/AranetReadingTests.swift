import AranetKit
import Foundation
import Testing

@Suite(.tags(.types))
struct AranetReadingTests {
    @Test("Default initializer produces an empty unknown reading")
    func defaultInitializerIsEmpty() -> Void {
        let reading = AranetReading()

        #expect(reading.deviceType == .unknown)
        #expect(reading.name == "")
        #expect(reading.version == "")
        #expect(reading.temperature == nil)
        #expect(reading.humidity == nil)
        #expect(reading.co2 == nil)
        #expect(reading.pressure == nil)
        #expect(reading.radiationRate == nil)
        #expect(reading.radiationTotal == nil)
        #expect(reading.radiationDuration == nil)
        #expect(reading.radonConcentration == nil)
        #expect(reading.battery == 0)
        #expect(reading.status == nil)
        #expect(reading.interval == nil)
        #expect(reading.ago == nil)
    }

    @Test("Memberwise initializer stores every field")
    func memberwiseInitializerStoresEveryField() -> Void {
        let reading = AranetReading(
            deviceType: .aranetRadon,
            name: "Aranet Radon 0A1B2",
            version: "v1.0.0",
            temperature: Measurement(value: 18, unit: UnitTemperature.celsius),
            humidity: 61,
            co2: 777,
            pressure: Measurement(value: 998.7, unit: UnitPressure.hectopascals),
            radiationRate: Measurement(value: 120, unit: UnitRadiationDose.nanosieverts),
            radiationTotal: Measurement(value: 1_234, unit: UnitRadiationDose.nanosieverts),
            radiationDuration: 90_061,
            radonConcentration: Measurement(value: 148, unit: UnitRadioactivity.becquerelsPerCubicMeter),
            battery: 70,
            status: .yellow,
            interval: 300,
            ago: 120
        )

        #expect(reading.deviceType == .aranetRadon)
        #expect(reading.name == "Aranet Radon 0A1B2")
        #expect(reading.version == "v1.0.0")
        #expect(reading.temperature?.value == 18)
        #expect(reading.temperature?.unit == UnitTemperature.celsius)
        #expect(reading.humidity == 61)
        #expect(reading.co2 == 777)
        #expect(reading.pressure?.value == 998.7)
        #expect(reading.pressure?.unit == UnitPressure.hectopascals)
        #expect(reading.radiationRate?.value == 120)
        #expect(reading.radiationTotal?.value == 1_234)
        #expect(reading.radiationDuration == 90_061)
        #expect(reading.radonConcentration?.value == 148)
        #expect(reading.battery == 70)
        #expect(reading.status == .yellow)
        #expect(reading.interval == 300)
        #expect(reading.ago == 120)
    }

    @Test("Fixtures describe the sensors of each device type")
    func fixturesMatchDeviceCapabilities() -> Void {
        let aranet4 = ReadingFixtures.aranet4()
        let aranet2 = ReadingFixtures.aranet2()
        let radiation = ReadingFixtures.radiation()
        let radon = ReadingFixtures.radon()

        #expect(aranet4.co2 != nil && aranet4.pressure != nil && aranet4.radiationRate == nil)
        #expect(aranet2.co2 == nil && aranet2.temperature != nil && aranet2.status == nil)
        #expect(radiation.radiationRate != nil && radiation.radiationTotal != nil && radiation.temperature == nil)
        #expect(radon.radonConcentration != nil && radon.co2 == nil)
    }
}
