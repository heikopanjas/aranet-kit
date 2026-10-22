import AranetKit
import Foundation
import Testing

@testable import AranetKit

@Suite(.tags(.parsing))
struct ByteReaderTests {
    private static let bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F])

    @Test("Reads little-endian integers of every width and advances the offset")
    func readsEveryWidth() throws -> Void {
        var reader = ByteReader(Self.bytes)

        #expect(try reader.uint8() == 0x01)
        #expect(reader.offset == 1)
        #expect(try reader.uint16LE() == 0x0302)
        #expect(reader.offset == 3)
        #expect(try reader.uint32LE() == 0x0706_0504)
        #expect(reader.offset == 7)
        #expect(try reader.uint64LE() == 0x0F0E_0D0C_0B0A_0908)
        #expect(reader.offset == 15)
        #expect(reader.remaining == 0)
    }

    @Test("Reading exactly up to the end succeeds")
    func readingToTheEndSucceeds() throws -> Void {
        var reader = ByteReader(Data([0xAA, 0xBB]))

        #expect(try reader.uint16LE() == 0xBBAA)
        #expect(reader.remaining == 0)
    }

    @Test("Reading one byte past the end throws invalidData")
    func readingPastTheEndThrows() -> Void {
        var reader = ByteReader(Data([0xAA, 0xBB, 0xCC]))

        #expect(throws: AranetError.invalidData) {
            try reader.uint32LE()
        }
        #expect(reader.offset == 0, "A failed read must not consume bytes")
    }

    @Test("Each width fails when fewer bytes remain than it needs")
    func eachWidthChecksBounds() -> Void {
        var reader = ByteReader(Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]))

        #expect(throws: AranetError.invalidData) {
            try reader.uint64LE()
        }

        var empty = ByteReader(Data())
        #expect(throws: AranetError.invalidData) {
            try empty.uint8()
        }
        #expect(throws: AranetError.invalidData) {
            try empty.uint16LE()
        }
    }

    @Test("Skipping advances without decoding and is bounds checked")
    func skipIsBoundsChecked() throws -> Void {
        var reader = ByteReader(Self.bytes)

        try reader.skip(14)
        #expect(reader.offset == 14)
        #expect(try reader.uint8() == 0x0F)

        #expect(throws: AranetError.invalidData) {
            try reader.skip(1)
        }
    }

    @Test("Negative skips are rejected")
    func negativeSkipIsRejected() -> Void {
        var reader = ByteReader(Self.bytes, offset: 4)

        #expect(throws: AranetError.invalidData) {
            try reader.skip(-1)
        }
        #expect(reader.offset == 4)
    }

    @Test("An initial offset positions the first read")
    func initialOffset() throws -> Void {
        var reader = ByteReader(Self.bytes, offset: 2)

        #expect(reader.remaining == 13)
        #expect(try reader.uint16LE() == 0x0403)
    }

    @Test("An initial offset beyond the payload makes every read fail")
    func offsetBeyondPayload() -> Void {
        var reader = ByteReader(Data([0x01]), offset: 5)

        #expect(reader.remaining == 0)
        #expect(throws: AranetError.invalidData) {
            try reader.uint8()
        }
    }

    @Test("Data slices with a non-zero start index are read relative to the slice")
    func sliceWithNonZeroStartIndex() throws -> Void {
        let slice = Self.bytes[3...]
        var reader = ByteReader(slice)

        #expect(slice.startIndex == 3)
        #expect(try reader.uint8() == 0x04)
        #expect(try reader.uint16LE() == 0x0605)
    }
}
