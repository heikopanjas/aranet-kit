import Foundation
import Testing

/// A fake `sleep` that suspends callers until the test releases them, recording every requested delay.
///
/// Cancelling a suspended caller's task resumes it by throwing `CancellationError`, as `Task.sleep` does.
@MainActor
final class SleepGate {
    private var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    private(set) var requestedDelays: [TimeInterval] = []

    /// When false, cancelling a sleeping task leaves it suspended until `release()` or `interrupt()`, like a timer that ignores cancellation.
    var honorsCancellation = true

    /// Number of callers currently suspended.
    var waiting: Int {
        return self.waiters.count
    }

    func sleep(_ delay: TimeInterval) async throws -> Void {
        self.requestedDelays.append(delay)
        let id = UUID()

        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                self.waiters[id] = continuation
            }
        } onCancel: {
            Task { @MainActor in
                self.cancelWaiter(id)
            }
        }
    }

    /// Resumes every suspended caller normally.
    ///
    /// Records an issue when nobody is sleeping: the caller the test meant to release has not reached its sleep yet,
    /// and would otherwise sleep forever. Wait for `waiting` or `requestedDelays` before releasing.
    func release() -> Void {
        let waiters = self.waiters.values
        if waiters.isEmpty == true {
            Issue.record("release() found no sleeping caller")
        }
        self.waiters = [:]
        for waiter in waiters {
            waiter.resume()
        }
    }

    /// Resumes every suspended caller by throwing `CancellationError`; like `release()`, nobody sleeping is an issue.
    func interrupt() -> Void {
        let waiters = self.waiters.values
        if waiters.isEmpty == true {
            Issue.record("interrupt() found no sleeping caller")
        }
        self.waiters = [:]
        for waiter in waiters {
            waiter.resume(throwing: CancellationError())
        }
    }

    private func cancelWaiter(_ id: UUID) -> Void {
        guard self.honorsCancellation == true, let waiter = self.waiters.removeValue(forKey: id) else { return }
        waiter.resume(throwing: CancellationError())
    }
}
