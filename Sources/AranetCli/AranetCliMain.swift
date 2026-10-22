//
// AranetCliMain.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import ArgumentParser
import Foundation

/// Entry point that reports parsing and runtime failures as JSON when `--json` is used.
@main
enum AranetCliMain {
    static func main() async -> Void {
        await Self.run(arguments: CliEnvironment.current.arguments)
    }

    /// Parses and runs the command for `arguments`, exiting the process on any error.
    static func run(arguments: [String]) async -> Void {
        let environment = CliEnvironment.current.with(arguments: arguments)
        await CliEnvironment.$current.withValue(environment) {
            do {
                var command = try AranetCli.parseAsRoot(arguments)

                if var asyncCommand = command as? AsyncParsableCommand {
                    try await asyncCommand.run()
                }
                else {
                    try command.run()
                }
            }
            catch {
                Self.exit(withError: error)
            }
        }
    }

    private static func exit(withError error: any Error) -> Never {
        switch ExitPlan.make(for: error, jsonRequested: AranetCli.jsonRequested) {
            case .passThrough:
                AranetCli.exit(withError: error)
            case .json(let message, let code):
                if let message {
                    JsonOutput.emitError(message)
                }
                AranetCli.exit(withError: code)
        }
    }
}
