//
// ReadingMonitor.swift
// AranetKit
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Reads one device repeatedly, timed to the device's own update interval.
///
/// The monitor owns no Bluetooth state: reading, sleeping, and publishing are injected so the
/// loop can run under test with fakes. ``AranetClient/monitor(from:)`` composes it with the real client.
@MainActor
struct ReadingMonitor {
    typealias Read = @MainActor (AranetDevice) async throws -> AranetReading
    typealias Sleep = @MainActor (TimeInterval) async throws -> Void
    typealias Publish = @MainActor (AranetDevice, AranetReading) -> Void

    let read: Read
    let sleep: Sleep
    let publish: Publish

    init(read: @escaping Read, sleep: @escaping Sleep, publish: @escaping Publish) {
        self.read = read
        self.sleep = sleep
        self.publish = publish
    }

    /// Reads once immediately, then after every expected device update, until the task is cancelled or a read fails.
    ///
    /// Every reading is yielded as `.success` and published; the first failure is yielded as `.failure`.
    /// The stream is finished on every exit path.
    func run(for device: AranetDevice, into continuation: AsyncStream<Result<AranetReading, any Error>>.Continuation) async -> Void {
        defer { continuation.finish() }

        let initialReading: AranetReading
        do {
            initialReading = try await self.read(device)
        }
        catch {
            continuation.yield(.failure(error))
            return
        }

        continuation.yield(.success(initialReading))
        self.publish(device, initialReading)

        guard let initialInterval = initialReading.interval else {
            continuation.yield(.failure(AranetError.invalidData))
            return
        }

        var interval = TimeInterval(initialInterval)
        var delay = MonitorSchedule.nextDelay(interval: interval, ago: initialReading.ago)

        while Task.isCancelled == false {
            do {
                try await self.sleep(delay)
            }
            catch {
                return
            }

            if Task.isCancelled == true {
                return
            }

            let reading: AranetReading
            do {
                reading = try await self.read(device)
            }
            catch {
                continuation.yield(.failure(error))
                return
            }

            continuation.yield(.success(reading))
            self.publish(device, reading)

            if let newInterval = reading.interval {
                interval = TimeInterval(newInterval)
            }
            delay = MonitorSchedule.nextDelay(interval: interval, ago: reading.ago)
        }
    }
}
