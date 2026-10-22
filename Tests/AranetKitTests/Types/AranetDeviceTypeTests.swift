import AranetKit
import Foundation
import Testing

@Suite(.tags(.types))
struct AranetDeviceTypeTests {
    private static let rawValues: [UInt8] = [0, 1, 2, 3, 255]
    private static let cases: [AranetDeviceType] = [.aranet4, .aranet2, .aranetRadiation, .aranetRadon, .unknown]
    private static let names = ["Aranet4", "Aranet2", "Aranet Radiation", "Aranet Radon Plus", "Unknown Aranet Device"]

    @Test("Raw values round trip", arguments: zip(AranetDeviceTypeTests.rawValues, AranetDeviceTypeTests.cases))
    func rawValuesRoundTrip(rawValue: UInt8, expected: AranetDeviceType) -> Void {
        #expect(AranetDeviceType(rawValue: rawValue) == expected)
        #expect(expected.rawValue == rawValue)
    }

    @Test("Undefined raw values are rejected", arguments: [UInt8(4), 5, 16, 254])
    func undefinedRawValuesAreRejected(rawValue: UInt8) -> Void {
        #expect(AranetDeviceType(rawValue: rawValue) == nil)
    }

    @Test("Names are human readable", arguments: zip(AranetDeviceTypeTests.cases, AranetDeviceTypeTests.names))
    func namesAreHumanReadable(deviceType: AranetDeviceType, expected: String) -> Void {
        #expect(deviceType.name == expected)
    }
}
