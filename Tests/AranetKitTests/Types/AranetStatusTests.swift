import AranetKit
import Foundation
import Testing

@Suite(.tags(.types))
struct AranetStatusTests {
    private static let cases: [AranetStatus] = [.off, .under, .over, .dash]
    private static let names = ["OFF", "UNDER", "OVER", "DASH"]

    @Test("Raw values round trip", arguments: zip([UInt8(0), 1, 2, 3], AranetStatusTests.cases))
    func rawValuesRoundTrip(rawValue: UInt8, expected: AranetStatus) -> Void {
        #expect(AranetStatus(rawValue: rawValue) == expected)
        #expect(expected.rawValue == rawValue)
    }

    @Test("Undefined raw values are rejected", arguments: [UInt8(4), 0x0F, 0xFF])
    func undefinedRawValuesAreRejected(rawValue: UInt8) -> Void {
        #expect(AranetStatus(rawValue: rawValue) == nil)
    }

    @Test("Names are upper case", arguments: zip(AranetStatusTests.cases, AranetStatusTests.names))
    func namesAreUpperCase(status: AranetStatus, expected: String) -> Void {
        #expect(status.name == expected)
    }
}
