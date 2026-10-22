//
// AranetLog.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation
import os

/// Diagnostic logging for the client.
///
/// The client receives a sink at construction time; the default writes to the unified log at debug level,
/// and tests inject a recorder. ``AranetClient/verbose`` additionally echoes every message to standard output.
public enum AranetLog {
    public typealias Sink = @MainActor @Sendable (String) -> Void

    private static let logger = Logger(subsystem: "com.panjas.aranet-kit", category: "client")

    /// Writes to the unified log at debug level.
    public static let standard: Sink = { message in
        AranetLog.logger.debug("\(message, privacy: .public)")
    }
}
