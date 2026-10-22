//
// WaiterRegistry.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

/// Continuations that wait for the same event, resumed together exactly once.
///
/// Replaces single-slot continuation properties, which a second concurrent caller would overwrite
/// and leave the first caller suspended forever.
struct WaiterRegistry<Value: Sendable> {
    private var continuations: [CheckedContinuation<Value, any Error>] = []

    var count: Int {
        return self.continuations.count
    }

    var isEmpty: Bool {
        return self.continuations.isEmpty
    }

    mutating func add(_ continuation: CheckedContinuation<Value, any Error>) -> Void {
        self.continuations.append(continuation)
    }

    mutating func resumeAll(returning value: Value) -> Void {
        let waiters = self.continuations
        self.continuations = []
        for waiter in waiters {
            waiter.resume(returning: value)
        }
    }

    mutating func resumeAll(throwing error: any Error) -> Void {
        let waiters = self.continuations
        self.continuations = []
        for waiter in waiters {
            waiter.resume(throwing: error)
        }
    }
}
