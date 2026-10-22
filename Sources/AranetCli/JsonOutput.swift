//
// JsonOutput.swift
// AranetCli
//
// Machine-readable output for script and agent usage (--json).
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit
import Foundation

/// Encodes payloads as JSON on standard output, including errors.
enum JsonOutput {
    /// Raised when a payload cannot be encoded; the message was already written to standard error.
    struct EncodingFailure: Error, Equatable {}

    private static func encoder(pretty: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting =
            pretty == true
            ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Encodes a payload, reporting failures on standard error.
    static func text<T: Encodable>(for value: T, pretty: Bool) throws -> String {
        do {
            let data = try Self.encoder(pretty: pretty).encode(value)
            return String(decoding: data, as: UTF8.self)
        }
        catch {
            CliEnvironment.current.writeError("error: could not encode JSON output: \(error.localizedDescription)")
            throw EncodingFailure()
        }
    }

    /// Writes a JSON payload to standard output.
    ///
    /// - Parameters:
    ///   - value: The payload to encode.
    ///   - pretty: Pass `false` for single-line output, as required by the
    ///     newline-delimited stream of the `monitor` command.
    /// - Throws: ``EncodingFailure`` when the payload cannot be encoded.
    static func emit<T: Encodable>(_ value: T, pretty: Bool = true) throws -> Void {
        CliEnvironment.current.printLine(try Self.text(for: value, pretty: pretty))
    }

    /// Writes a JSON error payload to standard output as a single line.
    ///
    /// JSON mode keeps every output stream machine-readable, so errors are written
    /// to stdout alongside the data instead of stderr.
    static func emitError(_ message: String, device: String? = nil) -> Void {
        guard let text = try? Self.text(for: JsonError(error: message, device: device), pretty: false) else {
            return
        }

        CliEnvironment.current.printLine(text)
    }

    /// Writes a JSON error payload derived from any error.
    static func emitError(_ error: any Error, device: String? = nil) -> Void {
        Self.emitError(error.localizedDescription, device: device)
    }
}
