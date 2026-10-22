//
// ByteReader.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Reads little-endian integers from a payload with bounds checking.
///
/// Every read advances `offset`. Reading past the end throws ``AranetError/invalidData``
/// instead of trapping, so malformed payloads surface as errors.
struct ByteReader {
    private let data: Data
    private(set) var offset: Int

    init(_ data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    /// Number of bytes left after the current offset.
    var remaining: Int {
        return max(self.data.count - self.offset, 0)
    }

    mutating func uint8() throws -> UInt8 {
        let slice = try self.consume(1)
        return slice[slice.startIndex]
    }

    mutating func uint16LE() throws -> UInt16 {
        return UInt16(littleEndian: try self.load(UInt16.self))
    }

    mutating func uint32LE() throws -> UInt32 {
        return UInt32(littleEndian: try self.load(UInt32.self))
    }

    mutating func uint64LE() throws -> UInt64 {
        return UInt64(littleEndian: try self.load(UInt64.self))
    }

    mutating func skip(_ count: Int) throws -> Void {
        _ = try self.consume(count)
    }

    private mutating func load<Value: FixedWidthInteger>(_ type: Value.Type) throws -> Value {
        let slice = try self.consume(MemoryLayout<Value>.size)
        return slice.withUnsafeBytes { $0.loadUnaligned(as: Value.self) }
    }

    private mutating func consume(_ count: Int) throws -> Data.SubSequence {
        guard count >= 0, self.offset >= 0, self.offset + count <= self.data.count else {
            throw AranetError.invalidData
        }

        let start = self.data.startIndex + self.offset
        let slice = self.data[start ..< start + count]
        self.offset += count
        return slice
    }
}
