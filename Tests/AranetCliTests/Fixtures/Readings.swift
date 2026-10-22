import AranetKit
import Foundation

/// Ready-made readings for every device type, with values chosen so that each formatted output is distinct.
enum ReadingFixtures {
    static let aranet4Name = "Aranet4 1A2B3"
    static let aranet2Name = "Aranet2 4C5D6"
    static let radiationName = "Aranet Radiation 7E8F9"
    static let radonName = "Aranet Radon 0A1B2"
    static let firmwareVersion = "v1.4.14"

    static func aranet4(
        co2: UInt16 = 812,
        temperature: Double = 21.5,
        humidity: UInt8 = 43,
        pressure: Double = 1013.2,
        battery: UInt8 = 87,
        status: AranetStatusColor? = .green,
        interval: UInt16? = 300,
        ago: UInt16? = 42,
        version: String = ReadingFixtures.firmwareVersion
    ) -> AranetReading {
        return AranetReading(
            deviceType: .aranet4,
            name: Self.aranet4Name,
            version: version,
            temperature: Measurement(value: temperature, unit: UnitTemperature.celsius),
            humidity: humidity,
            co2: co2,
            pressure: Measurement(value: pressure, unit: UnitPressure.hectopascals),
            battery: battery,
            status: status,
            interval: interval,
            ago: ago
        )
    }

    static func aranet2(
        temperature: Double = 19.25,
        humidity: UInt8 = 55,
        battery: UInt8 = 64,
        interval: UInt16? = 600,
        ago: UInt16? = 17
    ) -> AranetReading {
        return AranetReading(
            deviceType: .aranet2,
            name: Self.aranet2Name,
            version: Self.firmwareVersion,
            temperature: Measurement(value: temperature, unit: UnitTemperature.celsius),
            humidity: humidity,
            battery: battery,
            interval: interval,
            ago: ago
        )
    }

    static func radiation(
        rateNanosievertsPerHour: Double = 120,
        totalNanosieverts: Double = 1_234_567,
        duration: UInt64 = 90_061,
        battery: UInt8 = 91,
        status: AranetStatusColor? = .green,
        interval: UInt16? = 60,
        ago: UInt16? = 5
    ) -> AranetReading {
        return AranetReading(
            deviceType: .aranetRadiation,
            name: Self.radiationName,
            version: Self.firmwareVersion,
            radiationRate: Measurement(value: rateNanosievertsPerHour, unit: UnitRadiationDose.nanosieverts),
            radiationTotal: Measurement(value: totalNanosieverts, unit: UnitRadiationDose.nanosieverts),
            radiationDuration: duration,
            battery: battery,
            status: status,
            interval: interval,
            ago: ago
        )
    }

    static func radon(
        becquerelsPerCubicMeter: Double = 148,
        temperature: Double = 18,
        humidity: UInt8 = 61,
        pressure: Double = 998.7,
        battery: UInt8 = 70,
        status: AranetStatusColor? = .yellow,
        interval: UInt16? = 300,
        ago: UInt16? = 120
    ) -> AranetReading {
        return AranetReading(
            deviceType: .aranetRadon,
            name: Self.radonName,
            version: Self.firmwareVersion,
            temperature: Measurement(value: temperature, unit: UnitTemperature.celsius),
            humidity: humidity,
            pressure: Measurement(value: pressure, unit: UnitPressure.hectopascals),
            radonConcentration: Measurement(value: becquerelsPerCubicMeter, unit: UnitRadioactivity.becquerelsPerCubicMeter),
            battery: battery,
            status: status,
            interval: interval,
            ago: ago
        )
    }
}
