import Foundation
import Testing

@testable import AranetKit

@MainActor
@Suite(.tags(.bluetooth), .timeLimit(.minutes(1)))
struct WaiterRegistryTests {
    @MainActor
    private final class RegistryBox {
        var registry = WaiterRegistry<Int>()
    }

    private func wait(on box: RegistryBox) -> Task<Int, any Error> {
        return Task {
            try await withCheckedThrowingContinuation { continuation in
                box.registry.add(continuation)
            }
        }
    }

    @Test("A new registry is empty")
    func newRegistryIsEmpty() -> Void {
        let registry = WaiterRegistry<Int>()

        #expect(registry.isEmpty == true)
        #expect(registry.count == 0)
    }

    @Test("Every waiter receives the value and the registry empties")
    func resumeAllReturning() async throws -> Void {
        let box = RegistryBox()
        let first = self.wait(on: box)
        let second = self.wait(on: box)
        await settle("two waiters registered") { box.registry.count == 2 }

        #expect(box.registry.isEmpty == false)
        box.registry.resumeAll(returning: 7)

        #expect(try await first.value == 7)
        #expect(try await second.value == 7)
        #expect(box.registry.isEmpty == true)
    }

    @Test("Every waiter receives the error and the registry empties")
    func resumeAllThrowing() async throws -> Void {
        let box = RegistryBox()
        let first = self.wait(on: box)
        let second = self.wait(on: box)
        await settle("two waiters registered") { box.registry.count == 2 }

        box.registry.resumeAll(throwing: AranetError.bluetoothUnavailable)

        await #expect(throws: AranetError.bluetoothUnavailable) {
            try await first.value
        }
        await #expect(throws: AranetError.bluetoothUnavailable) {
            try await second.value
        }
        #expect(box.registry.count == 0)
    }

    @Test("Resuming an empty registry is a no-op")
    func resumingEmptyRegistry() -> Void {
        var registry = WaiterRegistry<Int>()

        registry.resumeAll(returning: 1)
        registry.resumeAll(throwing: AranetError.timeout)

        #expect(registry.isEmpty == true)
    }

    @Test("Waiters added after a resume form a new round")
    func laterWaitersFormNewRound() async throws -> Void {
        let box = RegistryBox()
        let first = self.wait(on: box)
        await settle("first waiter registered") { box.registry.count == 1 }
        box.registry.resumeAll(returning: 1)
        #expect(try await first.value == 1)

        let second = self.wait(on: box)
        await settle("second waiter registered") { box.registry.count == 1 }
        box.registry.resumeAll(returning: 2)

        #expect(try await second.value == 2)
    }
}
