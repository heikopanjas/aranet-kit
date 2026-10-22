import AranetKit
import ArgumentParser
import Foundation
import Testing

@testable import AranetCli

@MainActor
@Suite(.tags(.cli), .timeLimit(.minutes(1)))
struct MonitorCommandTests {
    private let first = AranetDevice(id: UUID(), name: "Aranet4 1A2B3")
    private let second = AranetDevice(id: UUID(), name: "Aranet Radiation 7E8F9")

    private func run(_ arguments: [String]) async throws -> Void {
        var command = try AranetCli.Monitor.parse(arguments)
        try await command.run()
    }

    @Test("Prints every reading with a timestamp and stops when the stream ends", .cli())
    func printsReadings() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.scriptMonitor(for: self.first, readings: [ReadingFixtures.aranet4(co2: 500), ReadingFixtures.aranet4(co2: 600)])

        try await self.run(["1A2B3"])

        let lines = context.output.lines
        #expect(lines[0] == "Scanning for device '1A2B3'...")
        #expect(lines.contains("Monitoring started. Press Ctrl+C to stop.") == true)
        #expect(lines.filter { $0 == "\(CliEnvironmentTrait.fixedNow)" }.count == 2)
        #expect(context.output.contains("CO2:          500 ppm") == true)
        #expect(context.output.contains("CO2:          600 ppm") == true)
        #expect(lines.last == "Monitoring stopped.")
        #expect(context.client.monitoredDevices == [self.first])
    }

    @Test("JSON mode streams one object per line", .cli())
    func jsonMode() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.scriptMonitor(for: self.first, readings: [ReadingFixtures.aranet4(co2: 500), ReadingFixtures.aranet4(co2: 600)])

        try await self.run(["1A2B3", "--json"])

        let lines = context.output.lines
        #expect(lines.count == 2)
        for (line, co2) in zip(lines, [500, 600]) {
            let object = try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            #expect((object["co2"] as? [String: Any])?["value"] as? Int == co2)
            #expect(object["timestamp"] as? String == "2026-10-22T10:00:00Z")
        }
    }

    @Test("A failed device is reported and fails the command once monitoring ends", .cli())
    func failedDevice() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.scriptMonitor(for: self.first, readings: [ReadingFixtures.aranet4()], thenFailWith: AranetError.connectionFailed)

        await #expect(throws: ExitCode.failure) {
            try await self.run(["1A2B3"])
        }
        let lines = context.output.lines
        #expect(lines.contains("Error (Aranet4 1A2B3): Failed to connect to device") == true)
        #expect(lines.last == "Monitoring stopped.")
    }

    @Test("A failed device in JSON mode is reported as an error line", .cli())
    func failedDeviceJson() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.scriptMonitor(for: self.first, readings: [], thenFailWith: AranetError.readFailed)

        await #expect(throws: ExitCode.failure) {
            try await self.run(["1A2B3", "--json"])
        }
        #expect(context.output.lines == ["{\"device\":\"Aranet4 1A2B3\",\"error\":\"Failed to read characteristic\"}"])
    }

    @Test("Other devices keep being monitored when one fails", .cli())
    func otherDevicesContinue() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first, self.second])
        context.client.scriptMonitor(for: self.first, readings: [], thenFailWith: AranetError.timeout)
        let radiation = context.client.openMonitor(for: self.second)

        let command = Task {
            try await self.run(["1A2B3", "7E8F9"])
        }
        await settle("both devices monitored") { context.client.monitoredDevices.count == 2 }
        await settle("first device failure reported") { context.output.contains("Error (Aranet4 1A2B3): Operation timed out") }

        radiation.yield(.success(ReadingFixtures.radiation()))
        await settle("radiation reading printed") { context.output.contains("Dose rate:") }
        radiation.finish()

        await #expect(throws: ExitCode.failure) {
            try await command.value
        }
    }

    @Test("An interrupt stops monitoring cleanly", .cli())
    func interruptStopsMonitoring() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        let continuation = context.client.openMonitor(for: self.first)

        let command = Task {
            try await self.run(["1A2B3"])
        }
        await settle("device monitored") { context.client.monitoredDevices.count == 1 }
        continuation.yield(.success(ReadingFixtures.aranet4()))
        await settle("reading printed") { context.output.contains("CO2:          812 ppm") }

        context.interrupt.yield(())
        try await command.value

        #expect(context.output.lines.last == "Monitoring stopped.")
    }

    @Test("An interrupt after a device failed still fails the command", .cli())
    func interruptAfterFailure() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first, self.second])
        context.client.scriptMonitor(for: self.first, readings: [], thenFailWith: AranetError.timeout)
        _ = context.client.openMonitor(for: self.second)

        let command = Task {
            try await self.run(["1A2B3", "7E8F9"])
        }
        await settle("first device failure reported") { context.output.contains("Error (Aranet4 1A2B3): Operation timed out") }

        context.interrupt.yield(())

        await #expect(throws: ExitCode.failure) {
            try await command.value
        }
    }

    @Test("Monitoring continues when the interrupt source ends without an interrupt", .cli())
    func interruptSourceEnds() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.scriptMonitor(for: self.first, readings: [ReadingFixtures.aranet4()])
        context.interrupt.finish()

        try await self.run(["1A2B3"])

        #expect(context.output.contains("CO2:          812 ppm") == true)
        #expect(context.output.lines.last == "Monitoring stopped.")
    }

    @Test("Unmatched queries are warnings, not failures", .cli())
    func unmatchedQueriesAreWarnings() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.scriptMonitor(for: self.first, readings: [])

        try await self.run(["1A2B3", "nope"])

        #expect(context.output.lines.contains("Warning: Device 'nope' not found") == true)
        #expect(context.output.lines.last == "Monitoring stopped.")
    }

    @Test("Unmatched queries in JSON mode are error lines", .cli())
    func unmatchedQueriesJson() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.scriptMonitor(for: self.first, readings: [])

        try await self.run(["1A2B3", "nope", "--json"])

        #expect(context.output.lines == ["{\"device\":\"nope\",\"error\":\"Device 'nope' not found\"}"])
    }
}
