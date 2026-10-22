import AranetKit
import Foundation
import Testing

@testable import AranetCli

@Suite(.tags(.cli, .formatting))
struct TerminalOutputTests {
    private static let separator = "---------------------------------------"

    @Test("Aranet4 output lists every measurement")
    func aranet4Output() -> Void {
        let output = ReadingFixtures.aranet4().formatOutput()
        let lines = output.components(separatedBy: "\n")

        #expect(lines.first == Self.separator)
        #expect(lines.last == Self.separator)
        #expect(lines.contains("Connected: Aranet4 1A2B3 | v1.4.14") == true)
        #expect(lines.contains("Updated 42s ago. Intervals: 300s") == true)
        #expect(lines.contains("CO2:          812 ppm") == true)
        #expect(lines.contains("Temperature:  21.5 \u{00B0}C") == true)
        #expect(lines.contains("Humidity:     43 %") == true)
        #expect(lines.contains("Pressure:     1013.2 hPa") == true)
        #expect(lines.contains("Battery:      87 %") == true)
        #expect(lines.contains("Status Display: GREEN") == true)
        #expect(lines.contains("Age:          42s/300s") == true)
    }

    @Test("A version without a v prefix gets one")
    func versionPrefixIsAdded() -> Void {
        let output = ReadingFixtures.aranet4(version: "1.4.14").formatOutput()

        #expect(output.contains("Connected: Aranet4 1A2B3 | v1.4.14") == true)
    }

    @Test("An empty version is omitted")
    func emptyVersionIsOmitted() -> Void {
        let output = ReadingFixtures.aranet4(version: "").formatOutput()

        #expect(output.contains("Connected: Aranet4 1A2B3\n") == true)
        #expect(output.contains(" | ") == false)
    }

    @Test("Missing interval and age skip the freshness and age lines")
    func missingIntervalSkipsAgeLines() -> Void {
        let output = ReadingFixtures.aranet4(interval: nil, ago: nil).formatOutput()

        #expect(output.contains("Updated") == false)
        #expect(output.contains("Age:") == false)
    }

    @Test("A missing status skips the status line")
    func missingStatusSkipsStatusLine() -> Void {
        let output = ReadingFixtures.aranet4(status: nil).formatOutput()

        #expect(output.contains("Status Display") == false)
    }

    @Test("Aranet2 output has temperature and humidity only")
    func aranet2Output() -> Void {
        let output = ReadingFixtures.aranet2().formatOutput()

        #expect(output.contains("Temperature:  19.2 \u{00B0}C") == true || output.contains("Temperature:  19.3 \u{00B0}C") == true)
        #expect(output.contains("Humidity:     55 %") == true)
        #expect(output.contains("Battery:      64 %") == true)
        #expect(output.contains("Age:          17s/600s") == true)
        #expect(output.contains("CO2") == false)
        #expect(output.contains("Pressure") == false)
        #expect(output.contains("Status Display") == false)
    }

    @Test("Radiation output converts to microsieverts and millisieverts")
    func radiationOutput() -> Void {
        let output = ReadingFixtures.radiation().formatOutput()

        #expect(output.contains("Dose rate:    0.12 \u{00B5}Sv/h") == true)
        #expect(output.contains("Dose total:   1.2346 mSv/1d 1h 1m") == true)
        #expect(output.contains("Battery:      91 %") == true)
        #expect(output.contains("Status Display: GREEN") == true)
        #expect(output.contains("Age:          5s/60s") == true)
    }

    @Test(
        "Radiation duration formatting",
        arguments: zip(
            [UInt64(59), 60, 3_600, 3_660, 86_400, 90_061, 1_000_000],
            ["0m", "1m", "1h 0m", "1h 1m", "1d 0m", "1d 1h 1m", "11d 13h 46m"]
        )
    )
    func radiationDurationFormatting(duration: UInt64, expected: String) -> Void {
        let output = ReadingFixtures.radiation(duration: duration).formatOutput()

        #expect(output.contains("mSv/\(expected)\n") == true, "Output was: \(output)")
    }

    @Test("Radiation output without a total skips the total line")
    func radiationWithoutTotal() -> Void {
        let reading = AranetReading(
            deviceType: .aranetRadiation,
            name: "Aranet Radiation",
            radiationRate: Measurement(value: 250, unit: UnitRadiationDose.nanosieverts),
            battery: 50
        )
        let output = reading.formatOutput()

        #expect(output.contains("Dose rate:    0.25 \u{00B5}Sv/h") == true)
        #expect(output.contains("Dose total") == false)
    }

    @Test("Radon output lists concentration and climate values")
    func radonOutput() -> Void {
        let output = ReadingFixtures.radon().formatOutput()

        #expect(output.contains("Radon Conc.:  148 Bq/m\u{00B3}") == true)
        #expect(output.contains("Temperature:  18.0 \u{00B0}C") == true)
        #expect(output.contains("Humidity:     61 %") == true)
        #expect(output.contains("Pressure:     998.7 hPa") == true)
        #expect(output.contains("Status Display: YELLOW") == true)
    }

    @Test("Unknown device types are reported as such")
    func unknownDeviceOutput() -> Void {
        let output = AranetReading(name: "Mystery").formatOutput()

        #expect(output.contains("Connected: Mystery\n") == true)
        #expect(output.contains("Unknown device type") == true)
    }
}
