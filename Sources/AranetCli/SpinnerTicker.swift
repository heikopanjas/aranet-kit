//
// SpinnerTicker.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Schedules the spinner's repeating tick; the live ticker uses a main run loop timer, tests fire ticks by hand.
struct SpinnerTicker: Sendable {
    typealias Tick = @MainActor @Sendable () -> Void
    typealias Cancel = @MainActor () -> Void
    typealias Start = @MainActor @Sendable (_ interval: TimeInterval, _ tick: @escaping Tick) -> Cancel

    /// Starts ticking and returns the closure that stops it.
    let start: Start

    init(start: @escaping Start) {
        self.start = start
    }

    /// A timer on the main run loop in `.common` mode, so it keeps animating while the main actor is busy with other run loop work.
    static let live = SpinnerTicker { interval, tick in
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated {
                tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return {
            timer.invalidate()
        }
    }

    @MainActor
    func schedule(every interval: TimeInterval, _ tick: @escaping Tick) -> Cancel {
        return self.start(interval, tick)
    }
}
