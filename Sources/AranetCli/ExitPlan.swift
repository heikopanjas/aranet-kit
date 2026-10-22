//
// ExitPlan.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import ArgumentParser
import Foundation

/// How the process should end after an error, decided without side effects so it can be tested.
enum ExitPlan: Equatable {
    /// Let swift-argument-parser print its own diagnostic and choose the exit code.
    case passThrough
    /// Emit the message as a JSON error line (when present), then exit with the code.
    case json(message: String?, code: ExitCode)

    /// `ArgumentParser` writes plain-text diagnostics for anything thrown out of a command,
    /// which scripts and agents cannot parse, so JSON mode intercepts them. Help and version
    /// requests are not failures and keep their regular output.
    static func make(for error: any Error, jsonRequested: Bool) -> ExitPlan {
        guard jsonRequested == true else {
            return .passThrough
        }

        let code = AranetCli.exitCode(for: error)
        guard code != ExitCode.success else {
            return .passThrough
        }

        let message = AranetCli.message(for: error)
        return .json(message: message.isEmpty == true ? nil : message, code: code)
    }
}
