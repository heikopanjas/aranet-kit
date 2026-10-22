//
// CliEnvironment.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit
import Foundation

/// Everything the commands touch outside their own logic, so tests can substitute all of it.
///
/// The live environment talks to the real client, standard output, the terminal, the clock, and SIGINT.
/// `current` is a task-local, so a test installs its own environment for the duration of one command.
struct CliEnvironment: Sendable {
    typealias Output = @Sendable (String) -> Void
    typealias Interrupts = @Sendable () -> AsyncStream<Void>

    /// Creates the sensor client a command talks to.
    var makeClient: @MainActor @Sendable () -> any SensorClient
    /// Writes text to standard output without adding a newline.
    var write: Output
    /// Writes one line to standard error.
    var writeError: Output
    /// True when standard output is an interactive terminal.
    var isTerminal: Bool
    /// The current time, used for human-readable monitor timestamps.
    var now: @Sendable () -> Date
    /// The command-line arguments without the program name.
    var arguments: [String]
    /// Delivers one element per interrupt request (Ctrl+C).
    var interrupts: Interrupts

    @TaskLocal static var current = CliEnvironment.live

    static let live = CliEnvironment(
        makeClient: { AranetClient() },
        write: { text in
            Swift.print(text, terminator: "")
            fflush(stdout)
        },
        writeError: { line in
            FileHandle.standardError.write(Data((line + "\n").utf8))
        },
        isTerminal: isatty(STDOUT_FILENO) == 1,
        now: { Date() },
        arguments: Array(CommandLine.arguments.dropFirst()),
        interrupts: { CliEnvironment.signalInterrupts() }
    )

    /// Writes one line to standard output.
    func printLine(_ line: String) -> Void {
        self.write(line + "\n")
    }

    /// Returns a copy that parses the given arguments.
    func with(arguments: [String]) -> CliEnvironment {
        var copy = self
        copy.arguments = arguments
        return copy
    }

    /// A stream that yields whenever the process receives SIGINT; the default handler is disabled while it is consumed.
    private static func signalInterrupts() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        source.setEventHandler {
            continuation.yield(())
        }
        continuation.onTermination = { _ in
            source.cancel()
            signal(SIGINT, SIG_DFL)
        }
        source.resume()
        return stream
    }
}
