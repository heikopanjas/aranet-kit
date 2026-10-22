import Foundation
import Testing

@testable import AranetKit

@Suite(.tags(.parsing))
struct PayloadHexDumpTests {
    /// Builds the expected line from the documented column widths: range padded to 5, value padded to 36.
    private func line(range: String, value: String, description: String) -> String {
        let rangeColumn = range.padding(toLength: 5, withPad: " ", startingAt: 0)
        let valueColumn = value.padding(toLength: 36, withPad: " ", startingAt: 0)
        return "\(rangeColumn)  \(valueColumn) \(description)"
    }

    @Test("Full Aranet4 payload lists every field with its little-endian value")
    func fullAranet4Dump() -> Void {
        let lines = PayloadHexDump.lines(for: PayloadFixtures.aranet4Detailed, title: "Aranet4", fields: PayloadHexDump.aranet4Fields)

        #expect(lines.count == 10)
        #expect(lines.first == "=== Aranet4 (13 bytes) ===")
        #expect(lines.last == "===")
        #expect(lines[1] == self.line(range: "0-1", value: "2C 03 = 812", description: "CO2 (UInt16 LE, ppm)"))
        #expect(lines[4] == self.line(range: "6", value: "2B = 43", description: "Humidity (UInt8, %)"))
        #expect(lines[7] == self.line(range: "9-10", value: "2C 01 = 300", description: "Interval (UInt16 LE, sec)"))
        #expect(lines[8] == self.line(range: "11-12", value: "2A 00 = 42", description: "Ago (UInt16 LE, sec)"))
    }

    @Test("Fields starting past the end are omitted")
    func fieldsPastTheEndAreOmitted() -> Void {
        let lines = PayloadHexDump.lines(for: PayloadFixtures.aranet4Basic, title: "Aranet4", fields: PayloadHexDump.aranet4Fields)

        #expect(lines.count == 8)
        #expect(lines.first == "=== Aranet4 (9 bytes) ===")
        #expect(lines.contains { $0.contains("Interval") } == false)
    }

    @Test("Fields ending past the end are clamped to the available bytes")
    func fieldsAreClamped() -> Void {
        let data = Data([0x04, 0x00, 0x3C, 0x00, 0x05, 0x00, 0x5B, 0xB0, 0x04])
        let lines = PayloadHexDump.lines(for: data, title: "Aranet Radiation", fields: PayloadHexDump.radiationFields)

        #expect(lines.count == 7)
        #expect(lines[5] == self.line(range: "7-10", value: "B0 04 = 1200", description: "Rate (UInt32 LE, nSv/h)"))
    }

    @Test("Multi-byte values are assembled little-endian")
    func littleEndianAssembly() -> Void {
        let lines = PayloadHexDump.lines(for: PayloadFixtures.radiationPaired, title: "Aranet Radiation", fields: PayloadHexDump.radiationFields)

        #expect(lines.count == 10)
        #expect(lines[6] == self.line(range: "11-18", value: "87 D6 12 00 00 00 00 00 = 1234567", description: "Total (UInt64 LE, nSv)"))
        #expect(lines[8] == self.line(range: "27", value: "05 = 5", description: "Status (0x05=G, 0x0A=Y, 0x0B=R)"))
    }

    @Test("Long values are truncated to the value column")
    func longValuesAreTruncated() -> Void {
        let data = Data(repeating: 0xFF, count: 48)
        let lines = PayloadHexDump.lines(for: data, title: "Aranet Radiation", fields: PayloadHexDump.radiationFields)
        let totalLine = lines[6]
        let valueColumn = String(totalLine.dropFirst(7).prefix(36))

        #expect(valueColumn == "FF FF FF FF FF FF FF FF = 1844674407")
        #expect(totalLine.hasSuffix(" Total (UInt64 LE, nSv)") == true)
    }

    @Test("An empty payload produces only the header and footer")
    func emptyPayload() -> Void {
        let lines = PayloadHexDump.lines(for: Data(), title: "Empty", fields: PayloadHexDump.aranet4Fields)

        #expect(lines == ["=== Empty (0 bytes) ===", "==="])
    }
}
