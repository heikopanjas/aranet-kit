//
// ProgressSpinner.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// A simple terminal progress spinner similar to Node.js ora.
@MainActor
final class ProgressSpinner {
    static let frames = ["\u{280B}", "\u{2819}", "\u{2839}", "\u{2838}", "\u{283C}", "\u{2834}", "\u{2826}", "\u{2827}", "\u{2807}", "\u{280F}"]
    static let interval: TimeInterval = 0.08

    private static let hideCursor = "\u{001B}[?25l"
    private static let showCursor = "\u{001B}[?25h"
    private static let clearLine = "\r\u{001B}[K"
    private static let resetColor = "\u{001B}[0m"
    private static let cyan = "\u{001B}[36m"
    private static let green = "\u{001B}[32m"
    private static let red = "\u{001B}[31m"

    private let write: CliEnvironment.Output
    private let ticker: SpinnerTicker
    private var message: String
    private var currentFrame = 0
    private var stopTicking: (@MainActor () -> Void)?

    init(message: String = "Loading", write: @escaping CliEnvironment.Output = CliEnvironment.current.write, ticker: SpinnerTicker = .live) {
        self.message = message
        self.write = write
        self.ticker = ticker
    }

    /// True while the spinner is animating.
    var isRunning: Bool {
        return self.stopTicking != nil
    }

    func start() -> Void {
        guard self.stopTicking == nil else { return }

        self.currentFrame = 0
        self.write(Self.hideCursor)
        self.render()
        self.stopTicking = self.ticker.schedule(every: Self.interval) { [weak self] in
            self?.render()
        }
    }

    func update(message: String) -> Void {
        self.message = message
    }

    func succeed(message: String? = nil) -> Void {
        self.stop(symbol: "\u{2713}", message: message, color: Self.green)
    }

    func fail(message: String? = nil) -> Void {
        self.stop(symbol: "\u{2717}", message: message, color: Self.red)
    }

    func stop(symbol: String = "", message: String? = nil, color: String = "") -> Void {
        self.stopTicking?()
        self.stopTicking = nil
        self.write(Self.clearLine)

        if symbol.isEmpty == false {
            self.write("\(color)\(symbol)\(Self.resetColor) \(message ?? self.message)\n")
        }

        self.write(Self.showCursor)
    }

    /// Draws the current frame and advances to the next one.
    func render() -> Void {
        let frame = Self.frames[self.currentFrame]
        self.write("\r\(Self.cyan)\(frame)\(Self.resetColor) \(self.message)")
        self.currentFrame = (self.currentFrame + 1) % Self.frames.count
    }
}
