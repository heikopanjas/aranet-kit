//
// ReadOperation.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// One in-flight read: its state machine, the caller waiting for the result, and the watchdog that bounds it.
@MainActor
final class ReadOperation {
    var session: ReadSession
    var continuation: CheckedContinuation<AranetReading, any Error>?
    var watchdog: Task<Void, Never>?

    init(session: ReadSession) {
        self.session = session
    }
}
