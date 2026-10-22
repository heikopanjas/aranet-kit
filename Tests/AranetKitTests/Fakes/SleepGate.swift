import Foundation

/// A fake `sleep` that suspends callers until the test releases them, recording every requested delay.
@MainActor
final class SleepGate {
    private var waiters: [CheckedContinuation<Void, any Error>] = []
    private(set) var requestedDelays: [TimeInterval] = []

    /// Number of callers currently suspended.
    var waiting: Int {
        return self.waiters.count
    }

    func sleep(_ delay: TimeInterval) async throws -> Void {
        self.requestedDelays.append(delay)
        try await withCheckedThrowingContinuation { continuation in
            self.waiters.append(continuation)
        }
    }

    /// Resumes every suspended caller normally.
    func release() -> Void {
        let waiters = self.waiters
        self.waiters = []
        for waiter in waiters {
            waiter.resume()
        }
    }

    /// Resumes every suspended caller by throwing, as `Task.sleep` does when its task is cancelled.
    func interrupt() -> Void {
        let waiters = self.waiters
        self.waiters = []
        for waiter in waiters {
            waiter.resume(throwing: CancellationError())
        }
    }
}
