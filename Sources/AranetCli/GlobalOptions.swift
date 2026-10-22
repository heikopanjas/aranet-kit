//
// GlobalOptions.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import ArgumentParser
import Foundation

/// Options shared by every subcommand.
struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false

    @Option(name: .shortAndLong, help: "Scan timeout in seconds")
    var timeout: Double = 15.0

    /// Hidden copy of the root-level `--json` flag.
    ///
    /// The visible declaration lives on the root command, but swift-argument-parser
    /// does not pass parent values to subcommands, so this keeps
    /// `aranet-cli <subcommand> ... --json` parseable without listing the flag twice
    /// in the help pages.
    @Flag(name: .customLong("json"), help: .hidden)
    var jsonFlag: Bool = false

    /// True when `--json` was given before or after the subcommand name.
    var json: Bool {
        return self.jsonFlag == true || AranetCli.jsonRequested == true
    }

    /// Library diagnostics are suppressed in JSON mode to keep stdout parseable.
    var clientVerbose: Bool {
        return self.json == false && self.verbose == true
    }

    /// Spinners are only useful on an interactive, non-verbose terminal.
    var showSpinner: Bool {
        return self.json == false && self.verbose == false && CliEnvironment.current.isTerminal == true
    }

    /// Human-readable status text is suppressed in JSON mode.
    var showStatusText: Bool {
        return self.json == false
    }
}
