import AranetKit
import Foundation
import Testing

@Suite(.tags(.types))
struct AranetStatusColorTests {
    private static let cases: [AranetStatusColor] = [.error, .green, .yellow, .red]
    private static let names = ["ERROR", "GREEN", "YELLOW", "RED"]
    private static let radiationBytes: [UInt8] = [0x05, 0x0A, 0x0B]
    private static let radiationColors: [AranetStatusColor] = [.green, .yellow, .red]

    @Test("Aranet4 status bytes map by raw value", arguments: zip([UInt8(0), 1, 2, 3], AranetStatusColorTests.cases))
    func aranet4RawValues(rawValue: UInt8, expected: AranetStatusColor) -> Void {
        #expect(AranetStatusColor(rawValue: rawValue) == expected)
    }

    @Test("Undefined Aranet4 status bytes are rejected", arguments: [UInt8(4), 5, 0x0A, 0xFF])
    func undefinedAranet4Bytes(rawValue: UInt8) -> Void {
        #expect(AranetStatusColor(rawValue: rawValue) == nil)
    }

    @Test("Names are upper case", arguments: zip(AranetStatusColorTests.cases, AranetStatusColorTests.names))
    func namesAreUpperCase(color: AranetStatusColor, expected: String) -> Void {
        #expect(color.name == expected)
    }

    @Test(
        "Radiation status bytes use their own encoding",
        arguments: zip(AranetStatusColorTests.radiationBytes, AranetStatusColorTests.radiationColors)
    )
    func radiationBytesMap(byte: UInt8, expected: AranetStatusColor) -> Void {
        #expect(AranetStatusColor.fromRadiationByte(byte) == expected)
    }

    @Test("Unknown radiation status bytes map to nil", arguments: [UInt8(0x00), 0x01, 0x02, 0x03, 0x04, 0x06, 0x09, 0x0C, 0xFF])
    func unknownRadiationBytesMapToNil(byte: UInt8) -> Void {
        #expect(AranetStatusColor.fromRadiationByte(byte) == nil)
    }
}
