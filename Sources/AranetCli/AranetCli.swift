//
// AranetCli.swift
// AranetCli
//
// Swift reimplementation of the Python aranet4 library
// Based on https://github.com/Anrijs/Aranet4-Python
//
// Copyright (c) 2022 Anrijs Jargans (original Python implementation)
// Copyright (c) 2025 Heiko Panjas (Swift reimplementation)
//
// SPDX-License-Identifier: MIT
//

import ArgumentParser
import Foundation

struct AranetCli: AsyncParsableCommand {
    /// Current tool version, reported by the root-level `--version` flag.
    static let toolVersion = "4.0.0"

    /// True when `--json` appears anywhere on the command line.
    ///
    /// Needed because errors are raised before, and after, a command is parsed.
    static var jsonRequested: Bool {
        return CliEnvironment.current.arguments.contains("--json")
    }

    static let configuration = CommandConfiguration(
        commandName: "aranet-cli",
        abstract: "Command-line tool for Aranet Bluetooth sensors",
        subcommands: [Scan.self, Read.self, Monitor.self]
    )

    @Flag(name: .customLong("version"), help: "Show the version.")
    var showVersion: Bool = false

    @Flag(
        name: .customLong("json"),
        help: "Emit machine-readable JSON only (script and agent mode)"
    )
    var json: Bool = false

    mutating func run() async throws -> Void {
        guard self.showVersion == true else {
            throw CleanExit.helpRequest(self)
        }

        CliEnvironment.current.printLine(Self.toolVersion)
    }
}
