import Foundation
import Testing

@testable import AranetKit

@MainActor
@Suite(.tags(.bluetooth, .monitoring), .timeLimit(.minutes(1)), .serialized)
struct AranetClientMonitorTests {
    private let device = AranetDevice(id: UUID(), name: "Aranet4 1A2B3")

    @Test("Monitoring reads, publishes, and reschedules from the device interval")
    func monitoringReadsAndPublishes() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)

        let first = await confirmation("reading published") { published in
            let token = NotificationCenter.default.addObserver(forName: .aranetReadingDidUpdate, object: nil, queue: nil) { notification in
                guard let posted = notification.userInfo?[AranetNotificationKey.device] as? AranetDevice,
                    posted.id == self.device.id
                else { return }
                published()
            }
            defer { NotificationCenter.default.removeObserver(token) }

            let consumer = Task { () -> Result<AranetReading, any Error>? in
                var iterator = harness.client.monitor(from: self.device).makeAsyncIterator()
                return await iterator.next()
            }
            await settle("connect requested") { harness.central.count(of: .connect(self.device.id)) == 1 }
            harness.completeAranet4Read(of: self.device.id)
            return await consumer.value
        }

        let reading = try #require(first).get()
        #expect(reading.co2 == 812)
        #expect(harness.log.contains("Reading sensor data...") == true)

        await settle("monitor sleeping until the next update") { harness.gate.requestedDelays.contains(261) }
        harness.gate.interrupt()
        await settle("monitor loop stopped") { harness.gate.waiting == 0 }
        #expect(harness.central.count(of: .connect(self.device.id)) == 1, "No read happens once the sleep is interrupted")
    }

    @Test("Cancelling the consuming task stops the monitoring loop")
    func cancellingConsumerStopsLoop() async throws -> Void {
        let harness = ClientHarness()
        harness.register(self.device)

        let consumer = Task { () -> [UInt16?] in
            var seen: [UInt16?] = []
            for await result in harness.client.monitor(from: self.device) {
                if case .success(let reading) = result {
                    seen.append(reading.co2)
                }
            }
            return seen
        }
        await settle("connect requested") { harness.central.count(of: .connect(self.device.id)) == 1 }
        harness.completeAranet4Read(of: self.device.id)
        await settle("monitor sleeping until the next update") { harness.gate.requestedDelays.contains(261) }

        consumer.cancel()
        let seen = await consumer.value

        #expect(seen == [812])
        await settle("monitor loop stopped") { harness.gate.waiting == 0 }
        #expect(harness.central.count(of: .connect(self.device.id)) == 1)
    }

    @Test("A failed read finishes the monitor stream with the error")
    func failedReadFinishesStream() async throws -> Void {
        let harness = ClientHarness()

        var results: [Result<AranetReading, any Error>] = []
        for await result in harness.client.monitor(from: self.device) {
            results.append(result)
        }

        let only = try #require(results.first)
        #expect(results.count == 1)
        #expect(throws: AranetError.deviceNotFound) {
            try only.get()
        }
    }
}
