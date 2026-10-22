import AranetKit
import Foundation
import Testing

@testable import AranetKit

@MainActor
@Suite(.tags(.monitoring), .timeLimit(.minutes(1)))
struct ReadingMonitorTests {
    private let device = AranetDevice(id: UUID(), name: "Aranet4 MONITOR")
    private let gate = SleepGate()

    @MainActor
    private final class PublishLog {
        private(set) var readings: [AranetReading] = []

        func publish(_ device: AranetDevice, _ reading: AranetReading) -> Void {
            self.readings.append(reading)
        }
    }

    private func start(
        _ script: ReadingScript,
        publish: PublishLog,
        sleep: @escaping ReadingMonitor.Sleep
    ) -> MonitorRun {
        let (stream, continuation) = AsyncStream.makeStream(of: Result<AranetReading, any Error>.self)
        let monitor = ReadingMonitor(read: { try await script.read($0) }, sleep: sleep, publish: { publish.publish($0, $1) })
        let task = Task {
            await monitor.run(for: self.device, into: continuation)
        }
        return MonitorRun(task: task, iterator: stream.makeAsyncIterator())
    }

    private struct MonitorRun {
        let task: Task<Void, Never>
        var iterator: AsyncStream<Result<AranetReading, any Error>>.Iterator
    }

    private func reading(from result: Result<AranetReading, any Error>?) throws -> AranetReading {
        return try #require(result).get()
    }

    @Test("Yields the initial reading immediately, then sleeps until the next device update")
    func yieldsInitialReadingThenSleeps() async throws -> Void {
        let script = ReadingScript([.success(ReadingFixtures.aranet4(interval: 300, ago: 42))])
        let publish = PublishLog()
        var run = self.start(script, publish: publish, sleep: self.gate.sleep)

        let first = try self.reading(from: await run.iterator.next())

        #expect(first.co2 == 812)
        #expect(script.readCount == 1)
        #expect(script.devices == [self.device])
        #expect(publish.readings == [first])
        #expect(self.gate.requestedDelays == [261])
        #expect(self.gate.waiting == 1)

        run.task.cancel()
        self.gate.release()
        #expect(await run.iterator.next() == nil)
        #expect(script.readCount == 1, "No read may happen after cancellation")
    }

    @Test("Yields every reading in order and reschedules from each one")
    func yieldsReadingsInOrder() async throws -> Void {
        let script = ReadingScript([
            .success(ReadingFixtures.aranet4(co2: 500, interval: 300, ago: 42)),
            .success(ReadingFixtures.aranet4(co2: 600, interval: 120, ago: 10)),
            .success(ReadingFixtures.aranet4(co2: 700, interval: 120, ago: nil))
        ])
        let publish = PublishLog()
        var run = self.start(script, publish: publish, sleep: self.gate.sleep)

        let first = try self.reading(from: await run.iterator.next())
        self.gate.release()
        let second = try self.reading(from: await run.iterator.next())
        self.gate.release()
        let third = try self.reading(from: await run.iterator.next())

        #expect([first.co2, second.co2, third.co2] == [500, 600, 700])
        #expect(publish.readings.map(\.co2) == [500, 600, 700])
        #expect(self.gate.requestedDelays == [261, 113, 123])

        run.task.cancel()
        self.gate.release()
        #expect(await run.iterator.next() == nil)
    }

    @Test("A failed initial read finishes the stream with the error")
    func initialReadFailure() async throws -> Void {
        let script = ReadingScript([.failure(AranetError.connectionFailed)])
        let publish = PublishLog()
        var run = self.start(script, publish: publish, sleep: self.gate.sleep)

        let result = try #require(await run.iterator.next())

        #expect(throws: AranetError.connectionFailed) {
            try result.get()
        }
        #expect(await run.iterator.next() == nil)
        #expect(publish.readings.isEmpty == true)
        #expect(self.gate.requestedDelays.isEmpty == true)
    }

    @Test("A failed later read finishes the stream after the readings that succeeded")
    func laterReadFailure() async throws -> Void {
        let script = ReadingScript([
            .success(ReadingFixtures.aranet4(interval: 60, ago: 5)),
            .failure(AranetError.timeout)
        ])
        let publish = PublishLog()
        var run = self.start(script, publish: publish, sleep: self.gate.sleep)

        _ = try self.reading(from: await run.iterator.next())
        self.gate.release()
        let result = try #require(await run.iterator.next())

        #expect(throws: AranetError.timeout) {
            try result.get()
        }
        #expect(await run.iterator.next() == nil)
        #expect(publish.readings.count == 1)
    }

    @Test("A reading without an interval cannot be scheduled and finishes the stream")
    func missingIntervalFinishesStream() async throws -> Void {
        let script = ReadingScript([.success(ReadingFixtures.aranet4(interval: nil, ago: nil))])
        let publish = PublishLog()
        var run = self.start(script, publish: publish, sleep: self.gate.sleep)

        let first = try self.reading(from: await run.iterator.next())
        let result = try #require(await run.iterator.next())

        #expect(first.interval == nil)
        #expect(publish.readings == [first])
        #expect(throws: AranetError.invalidData) {
            try result.get()
        }
        #expect(await run.iterator.next() == nil)
        #expect(self.gate.requestedDelays.isEmpty == true)
    }

    @Test("Cancellation that interrupts the sleep ends the loop without another read")
    func cancellationInterruptingSleep() async throws -> Void {
        let script = ReadingScript([
            .success(ReadingFixtures.aranet4(interval: 60, ago: 5)),
            .success(ReadingFixtures.aranet4(interval: 60, ago: 5))
        ])
        let publish = PublishLog()
        var run = self.start(script, publish: publish, sleep: self.gate.sleep)

        _ = try self.reading(from: await run.iterator.next())
        run.task.cancel()
        self.gate.interrupt()

        #expect(await run.iterator.next() == nil)
        #expect(script.readCount == 1)
    }

    @Test("A sleep that throws for any reason ends the loop quietly")
    func throwingSleepEndsLoop() async throws -> Void {
        let script = ReadingScript([.success(ReadingFixtures.aranet4(interval: 60, ago: 5))])
        let publish = PublishLog()
        var run = self.start(script, publish: publish, sleep: { _ in throw AranetError.timeout })

        _ = try self.reading(from: await run.iterator.next())

        #expect(await run.iterator.next() == nil)
        #expect(script.readCount == 1)
    }

    @Test("Cancellation before the first read still finishes the stream")
    func cancellationBeforeFirstRead() async throws -> Void {
        let script = ReadingScript([.success(ReadingFixtures.aranet4(interval: 60, ago: 5))])
        let publish = PublishLog()
        let (stream, continuation) = AsyncStream.makeStream(of: Result<AranetReading, any Error>.self)
        let monitor = ReadingMonitor(read: { try await script.read($0) }, sleep: self.gate.sleep, publish: { publish.publish($0, $1) })

        let task = Task {
            await monitor.run(for: self.device, into: continuation)
        }
        task.cancel()
        await task.value

        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()

        #expect(first != nil, "The initial read is not cancellable; it is yielded before the loop checks cancellation")
        #expect(await iterator.next() == nil)
        #expect(self.gate.requestedDelays.isEmpty == true, "A cancelled task must not sleep")
    }
}
