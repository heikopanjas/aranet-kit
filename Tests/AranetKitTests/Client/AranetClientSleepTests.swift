import Foundation
import Testing

@testable import AranetKit

/// The production sleep is the one seam the fakes replace; these tests cover the real one.
@MainActor
@Suite(.tags(.bluetooth), .timeLimit(.minutes(1)))
struct AranetClientSleepTests {
    @Test("The system sleep suspends for at least the requested time")
    func sleepsForTheRequestedTime() async throws -> Void {
        let clock = ContinuousClock()
        let start = clock.now

        try await AranetClient.systemSleep(0.01)

        #expect(clock.now - start >= .milliseconds(10))
    }

    @Test("The system sleep throws CancellationError when its task is cancelled")
    func cancellationThrows() async -> Void {
        let sleeper = Task {
            try await AranetClient.systemSleep(60)
        }

        sleeper.cancel()

        await #expect(throws: CancellationError.self) {
            try await sleeper.value
        }
    }
}
