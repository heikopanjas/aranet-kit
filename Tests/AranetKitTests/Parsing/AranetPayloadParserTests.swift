import AranetKit
import CoreBluetooth
import Foundation
import Testing

@testable import AranetKit

@Suite(.tags(.parsing))
struct AranetPayloadParserTests {
    private static let aranet4Characteristics: [CBUUID?] = [
        AranetUUID.characteristicCurrentReadingsDetailed,
        AranetUUID.characteristicCurrentReadings,
        nil
    ]
    private static let typedCharacteristics: [CBUUID?] = [
        AranetUUID.characteristicCurrentReadingsAR2,
        AranetUUID.characteristicCurrentReadingsAR2Detailed
    ]

    private func parse(_ data: Data, characteristic: CBUUID? = AranetUUID.characteristicCurrentReadingsDetailed) throws -> AranetReading {
        return try AranetPayloadParser.reading(from: data, characteristic: characteristic, name: "Aranet TEST", version: "v1.2.3")
    }

    // MARK: - Aranet4

    @Test("Aranet4 detailed payload decodes every field", arguments: AranetPayloadParserTests.aranet4Characteristics)
    func aranet4DetailedPayload(characteristic: CBUUID?) throws -> Void {
        let reading = try self.parse(PayloadFixtures.aranet4Detailed, characteristic: characteristic)

        #expect(reading.deviceType == .aranet4)
        #expect(reading.name == "Aranet TEST")
        #expect(reading.version == "v1.2.3")
        #expect(reading.co2 == 812)
        #expect(reading.temperature == Measurement(value: 21.5, unit: UnitTemperature.celsius))
        #expect(reading.pressure == Measurement(value: 1013.2, unit: UnitPressure.hectopascals))
        #expect(reading.humidity == 43)
        #expect(reading.battery == 87)
        #expect(reading.status == .green)
        #expect(reading.interval == 300)
        #expect(reading.ago == 42)
        #expect(reading.radiationRate == nil)
        #expect(reading.radonConcentration == nil)
    }

    @Test("Aranet4 basic payload has no interval or age")
    func aranet4BasicPayload() throws -> Void {
        let reading = try self.parse(PayloadFixtures.aranet4Basic, characteristic: AranetUUID.characteristicCurrentReadings)

        #expect(reading.co2 == 812)
        #expect(reading.status == .green)
        #expect(reading.interval == nil)
        #expect(reading.ago == nil)
    }

    @Test("Aranet4 payloads between 9 and 12 bytes decode without interval or age", arguments: [9, 10, 11, 12])
    func aranet4TruncatedDetailedPayload(length: Int) throws -> Void {
        let reading = try self.parse(Data(PayloadFixtures.aranet4Detailed.prefix(length)))

        #expect(reading.co2 == 812)
        #expect(reading.battery == 87)
        #expect(reading.interval == nil)
        #expect(reading.ago == nil)
    }

    @Test("Aranet4 payloads shorter than 9 bytes are invalid", arguments: [0, 1, 8])
    func aranet4ShortPayloadIsInvalid(length: Int) -> Void {
        #expect(throws: AranetError.invalidData) {
            try self.parse(Data(PayloadFixtures.aranet4Detailed.prefix(length)))
        }
    }

    @Test("Aranet4 payloads longer than 13 bytes ignore the extra bytes")
    func aranet4LongerPayloadIgnoresExtraBytes() throws -> Void {
        let reading = try self.parse(PayloadFixtures.aranet4Detailed + Data([0xDE, 0xAD]))

        #expect(reading.interval == 300)
        #expect(reading.ago == 42)
    }

    @Test("Aranet4 saturated fields decode to their maximum and an undefined status becomes nil")
    func aranet4SaturatedFields() throws -> Void {
        let reading = try self.parse(PayloadFixtures.aranet4Saturated)

        #expect(reading.co2 == UInt16.max)
        #expect(reading.temperature?.value == Double(UInt16.max) / 20)
        #expect(reading.pressure?.value == Double(UInt16.max) / 10)
        #expect(reading.humidity == 100)
        #expect(reading.battery == 100)
        #expect(reading.status == nil)
        #expect(reading.interval == UInt16.max)
        #expect(reading.ago == UInt16.max)
    }

    @Test("Aranet4 status bytes map to colors", arguments: zip([UInt8(0), 1, 2, 3], [AranetStatusColor.error, .green, .yellow, .red]))
    func aranet4StatusBytes(byte: UInt8, expected: AranetStatusColor) throws -> Void {
        let reading = try self.parse(PayloadFixtures.replacing(PayloadFixtures.aranet4Detailed, byteAt: 8, with: byte))

        #expect(reading.status == expected)
    }

    // MARK: - Aranet Radiation

    @Test("Paired radiation payload divides the rate by ten", arguments: AranetPayloadParserTests.typedCharacteristics)
    func radiationPairedPayload(characteristic: CBUUID?) throws -> Void {
        let reading = try self.parse(PayloadFixtures.radiationPaired, characteristic: characteristic)

        #expect(reading.deviceType == .aranetRadiation)
        #expect(reading.radiationRate == Measurement(value: 120, unit: UnitRadiationDose.nanosieverts))
        #expect(reading.radiationTotal == Measurement(value: 1_234_567, unit: UnitRadiationDose.nanosieverts))
        #expect(reading.radiationDuration == 90_061)
        #expect(reading.battery == 91)
        #expect(reading.status == .green)
        #expect(reading.interval == 60)
        #expect(reading.ago == 5)
        #expect(reading.temperature == nil)
        #expect(reading.co2 == nil)
    }

    @Test("Detailed radiation payload keeps the rate as transmitted", arguments: AranetPayloadParserTests.typedCharacteristics)
    func radiationDetailedPayload(characteristic: CBUUID?) throws -> Void {
        let reading = try self.parse(PayloadFixtures.radiationDetailed, characteristic: characteristic)

        #expect(reading.radiationRate == Measurement(value: 120, unit: UnitRadiationDose.nanosieverts))
        #expect(reading.radiationTotal?.value == 1_234_567)
        #expect(reading.radiationDuration == 90_061)
        #expect(reading.status == .green)
    }

    @Test("Radiation payloads longer than 48 bytes are accepted")
    func radiationLongerPayload() throws -> Void {
        let data = PayloadFixtures.radiationDetailed + Data([0x01, 0x02])
        let reading = try self.parse(data, characteristic: AranetUUID.characteristicCurrentReadingsAR2Detailed)

        #expect(reading.radiationRate?.value == 120)
    }

    @Test("Radiation payloads of other lengths are invalid", arguments: [1, 2, 27, 29, 30, 47])
    func radiationOtherLengthsAreInvalid(length: Int) -> Void {
        let data = Data(PayloadFixtures.radiationDetailed.prefix(length))

        #expect(throws: AranetError.invalidData) {
            try self.parse(data, characteristic: AranetUUID.characteristicCurrentReadingsAR2Detailed)
        }
    }

    @Test(
        "Radiation status bytes use the radiation encoding",
        arguments: zip([UInt8(0x05), 0x0A, 0x0B, 0x00, 0x01], [AranetStatusColor?.some(.green), .yellow, .red, nil, nil])
    )
    func radiationStatusBytes(byte: UInt8, expected: AranetStatusColor?) throws -> Void {
        let data = PayloadFixtures.replacing(PayloadFixtures.radiationPaired, byteAt: 27, with: byte)
        let reading = try self.parse(data, characteristic: AranetUUID.characteristicCurrentReadingsAR2)

        #expect(reading.status == expected)
    }

    // MARK: - Aranet2

    @Test("Aranet2 payload decodes temperature and humidity", arguments: AranetPayloadParserTests.typedCharacteristics)
    func aranet2Payload(characteristic: CBUUID?) throws -> Void {
        let reading = try self.parse(PayloadFixtures.aranet2, characteristic: characteristic)

        #expect(reading.deviceType == .aranet2)
        #expect(reading.temperature == Measurement(value: 19.25, unit: UnitTemperature.celsius))
        #expect(reading.humidity == 55)
        #expect(reading.battery == 64)
        #expect(reading.interval == 600)
        #expect(reading.ago == 17)
        #expect(reading.status == nil)
        #expect(reading.co2 == nil)
        #expect(reading.pressure == nil)
    }

    @Test("Aranet2 payloads shorter than 10 bytes are invalid", arguments: [1, 5, 9])
    func aranet2ShortPayloadIsInvalid(length: Int) -> Void {
        let data = Data(PayloadFixtures.aranet2.prefix(length))

        #expect(throws: AranetError.invalidData) {
            try self.parse(data, characteristic: AranetUUID.characteristicCurrentReadingsAR2)
        }
    }

    // MARK: - Device type dispatch

    @Test("Radon Plus payloads are rejected until the layout is documented")
    func radonPlusIsRejected() -> Void {
        #expect(throws: AranetError.invalidData) {
            try self.parse(PayloadFixtures.radonPlus, characteristic: AranetUUID.characteristicCurrentReadingsAR2)
        }
    }

    @Test("Unknown device type bytes are rejected")
    func unknownTypeIsRejected() -> Void {
        #expect(throws: AranetError.invalidData) {
            try self.parse(PayloadFixtures.unknownType, characteristic: AranetUUID.characteristicCurrentReadingsAR2Detailed)
        }
    }

    @Test("An empty typed payload is rejected")
    func emptyTypedPayloadIsRejected() -> Void {
        #expect(throws: AranetError.invalidData) {
            try self.parse(Data(), characteristic: AranetUUID.characteristicCurrentReadingsAR2)
        }
    }

    @Test("A typed payload read through an Aranet4 characteristic is decoded as Aranet4")
    func typedPayloadThroughAranet4Characteristic() throws -> Void {
        let reading = try self.parse(PayloadFixtures.aranet2, characteristic: AranetUUID.characteristicCurrentReadingsDetailed)

        #expect(reading.deviceType == .aranet4)
        #expect(reading.co2 == 0x5802)
    }

    // MARK: - Hex dump selection

    @Test("Aranet4 characteristics produce an Aranet4 hex dump")
    func aranet4HexDump() -> Void {
        let lines = AranetPayloadParser.hexDumpLines(for: PayloadFixtures.aranet4Detailed, characteristic: nil)

        #expect(lines.first == "=== Aranet4 (13 bytes) ===")
        #expect(lines.count == PayloadHexDump.aranet4Fields.count + 2)
    }

    @Test("Radiation payloads produce a radiation hex dump")
    func radiationHexDump() -> Void {
        let characteristic = AranetUUID.characteristicCurrentReadingsAR2Detailed
        let lines = AranetPayloadParser.hexDumpLines(for: PayloadFixtures.radiationDetailed, characteristic: characteristic)

        #expect(lines.first == "=== Aranet Radiation (48 bytes) ===")
        #expect(lines.count == PayloadHexDump.radiationFields.count + 2)
    }

    @Test("Other typed payloads produce no hex dump")
    func otherTypedPayloadsProduceNoHexDump() -> Void {
        let characteristic = AranetUUID.characteristicCurrentReadingsAR2

        #expect(AranetPayloadParser.hexDumpLines(for: PayloadFixtures.aranet2, characteristic: characteristic).isEmpty == true)
        #expect(AranetPayloadParser.hexDumpLines(for: Data(), characteristic: characteristic).isEmpty == true)
    }
}
