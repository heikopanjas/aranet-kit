//
// ErrorPrinter.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit
import Foundation

/// Reports errors as text or, in JSON mode, as machine-readable lines.
enum ErrorPrinter {
    static func print(_ error: any Error, device: AranetDevice, json: Bool) -> Void {
        guard json == false else {
            JsonOutput.emitError(error, device: device.name)
            return
        }

        CliEnvironment.current.printLine("Error (\(device.name)): \(error.localizedDescription)")
    }

    static func print(_ message: String, json: Bool) -> Void {
        guard json == false else {
            JsonOutput.emitError(message)
            return
        }

        CliEnvironment.current.printLine("Error: \(message)")
    }
}
