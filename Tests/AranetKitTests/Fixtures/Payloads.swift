import Foundation

/// Byte payloads built from the tables in the "Aranet Device Data Formats" section of AGENTS.md.
///
/// Every multi-byte field uses asymmetric byte values so that endianness mistakes change the result.
enum PayloadFixtures {
    // MARK: - Aranet4 (F0CD3001 detailed, 13 bytes)
    //
    // CO2 812 (2C 03), temperature 21.5 C = 430 (AE 01), pressure 1013.2 hPa = 10132 (94 27),
    // humidity 43, battery 87, status 1 (green), interval 300 (2C 01), ago 42 (2A 00).
    static let aranet4Detailed = Data([0x2C, 0x03, 0xAE, 0x01, 0x94, 0x27, 0x2B, 0x57, 0x01, 0x2C, 0x01, 0x2A, 0x00])

    /// F0CD1503 basic layout: the first nine bytes of the detailed payload.
    static let aranet4Basic = Data(PayloadFixtures.aranet4Detailed.prefix(9))

    /// Aranet4 payload with every 16-bit field at its maximum and an undefined status byte.
    static let aranet4Saturated = Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x64, 0x64, 0x04, 0xFF, 0xFF, 0xFF, 0xFF])

    // MARK: - Aranet Radiation
    //
    // Shared bytes 0-27: type 0x04, byte 1 undocumented, interval 60 (3C 00), ago 5 (05 00), battery 91,
    // rate raw, total 1234567 nSv (87 D6 12 00 ...), duration 90061 s (CD 5F 01 00 ...), status 0x05 (green).

    /// F0CD1504 paired layout, 28 bytes, rate stored as nSv/h times ten: 1200 (B0 04 00 00) means 120 nSv/h.
    static let radiationPaired = Data([
        0x04, 0x00, 0x3C, 0x00, 0x05, 0x00, 0x5B,
        0xB0, 0x04, 0x00, 0x00,
        0x87, 0xD6, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xCD, 0x5F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x05
    ])

    /// F0CD3003 detailed layout, 48 bytes, rate stored as nSv/h: 120 (78 00 00 00), plus the extended block
    /// (total 1234 uSv, realtime duration 90000 s, four reserved zero bytes).
    static let radiationDetailed = Data([
        0x04, 0x00, 0x3C, 0x00, 0x05, 0x00, 0x5B,
        0x78, 0x00, 0x00, 0x00,
        0x87, 0xD6, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xCD, 0x5F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x05,
        0xD2, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x90, 0x5F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00
    ])

    // MARK: - Aranet2 (F0CD1504, 10 bytes)
    //
    // Type 0x02, interval 600 (58 02), ago 17 (11 00), battery 64, temperature 19.25 C = 385 (81 01),
    // humidity 55, status bits 0.
    static let aranet2 = Data([0x02, 0x58, 0x02, 0x11, 0x00, 0x40, 0x81, 0x01, 0x37, 0x00])

    /// Aranet Radon Plus reports type 0x03; its layout is not implemented.
    static let radonPlus = Data([0x03, 0x58, 0x02, 0x11, 0x00, 0x40, 0x81, 0x01, 0x37, 0x00])

    /// A device type byte no parser knows.
    static let unknownType = Data([0x07, 0x58, 0x02, 0x11, 0x00, 0x40, 0x81, 0x01, 0x37, 0x00])

    /// Returns a copy of `payload` with the given status byte at `offset`.
    static func replacing(_ payload: Data, byteAt offset: Int, with value: UInt8) -> Data {
        var bytes = [UInt8](payload)
        bytes[offset] = value
        return Data(bytes)
    }
}
