import AranetKit
import ArgumentParser
import Foundation
import Testing

@testable import AranetCli

@MainActor
@Suite(.tags(.cli))
struct ReadCommandTests {
    private let first = AranetDevice(id: UUID(), name: "Aranet4 1A2B3")
    private let second = AranetDevice(id: UUID(), name: "Aranet Radiation 7E8F9")

    private func run(_ arguments: [String]) async throws -> Void {
        var command = try AranetCli.Read.parse(arguments)
        try await command.run()
    }

    @Test("Reads one device and prints its readings", .cli())
    func readsOneDevice() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first, self.second])
        context.client.readResults[self.first.id] = .success(ReadingFixtures.aranet4())

        try await self.run(["1A2B3", "--timeout", "4"])

        #expect(context.output.lines[0] == "Scanning for device '1A2B3'...")
        #expect(context.output.lines[1] == "Reading from Aranet4 1A2B3...")
        #expect(context.output.contains("CO2:          812 ppm") == true)
        #expect(context.client.scanTimeouts == [4])
        #expect(context.client.readDevices == [self.first])
    }

    @Test("Reads several devices and prints them in query order", .cli())
    func readsSeveralDevices() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first, self.second])
        context.client.readResults[self.first.id] = .success(ReadingFixtures.aranet4())
        context.client.readResults[self.second.id] = .success(ReadingFixtures.radiation())

        try await self.run(["7E8F9", "1A2B3"])

        let text = context.output.text
        let radiationIndex = try #require(text.range(of: "Dose rate:")?.lowerBound)
        let co2Index = try #require(text.range(of: "CO2:")?.lowerBound)
        #expect(context.output.lines[0] == "Scanning for 2 devices...")
        #expect(context.output.lines[1] == "Reading from 2 devices...")
        #expect(radiationIndex < co2Index, "Output follows the order of the queries, not completion order")
        #expect(Set(context.client.readDevices) == [self.first, self.second])
    }

    @Test("JSON mode emits an array of readings with the environment's timestamp", .cli(arguments: ["read", "--json", "1A2B3"]))
    func jsonMode() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.readResults[self.first.id] = .success(ReadingFixtures.aranet4())

        try await self.run(["1A2B3", "--json"])

        let object = try JSONSerialization.jsonObject(with: Data(context.output.text.utf8))
        let readings = try #require(object as? [[String: Any]])
        #expect(readings.count == 1)
        #expect(readings[0]["device"] as? String == "Aranet4 1A2B3")
        #expect(readings[0]["timestamp"] as? String == "2026-10-22T10:00:00Z")
        #expect(context.output.contains("Scanning") == false)
    }

    @Test("A failed device is reported after the successful ones and fails the command", .cli())
    func partialFailure() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first, self.second])
        context.client.readResults[self.first.id] = .success(ReadingFixtures.aranet4())
        context.client.readResults[self.second.id] = .failure(AranetError.timeout)

        await #expect(throws: ExitCode.failure) {
            try await self.run(["1A2B3", "7E8F9"])
        }
        #expect(context.output.contains("CO2:          812 ppm") == true)
        #expect(context.output.lines.last == "Error (Aranet Radiation 7E8F9): Operation timed out")
    }

    @Test("Failures in JSON mode follow the array as error lines", .cli())
    func partialFailureJson() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first, self.second])
        context.client.readResults[self.first.id] = .success(ReadingFixtures.aranet4())
        context.client.readResults[self.second.id] = .failure(AranetError.connectionFailed)

        await #expect(throws: ExitCode.failure) {
            try await self.run(["1A2B3", "7E8F9", "--json"])
        }
        let lastLine = try #require(context.output.lines.last)
        let object = try JSONSerialization.jsonObject(with: Data(lastLine.utf8))
        let error = try #require(object as? [String: String])
        #expect(error == ["device": "Aranet Radiation 7E8F9", "error": "Failed to connect to device"])
    }

    @Test("Queries that match nothing are reported and fail the command", .cli())
    func unmatchedQuery() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.readResults[self.first.id] = .success(ReadingFixtures.aranet4())

        await #expect(throws: ExitCode.failure) {
            try await self.run(["1A2B3", "nope"])
        }
        #expect(context.output.lines.last == "Error: Device 'nope' not found")
    }

    @Test("When nothing matches the command fails before reading", .cli())
    func noMatches() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])

        await #expect(throws: ExitCode.failure) {
            try await self.run(["nope"])
        }
        #expect(context.output.lines.last == "Error: No matching devices found")
        #expect(context.client.readDevices.isEmpty == true)
    }

    @Test("A failed scan fails the command", .cli())
    func scanFailure() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .failure(AranetError.bluetoothUnsupported)

        await #expect(throws: ExitCode.failure) {
            try await self.run(["1A2B3"])
        }
        #expect(context.output.lines.last == "Error: Bluetooth is not supported on this device")
    }

    @Test("A failed scan in JSON mode emits a JSON error line", .cli())
    func scanFailureJson() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .failure(AranetError.bluetoothUnsupported)

        await #expect(throws: ExitCode.failure) {
            try await self.run(["1A2B3", "--json"])
        }
        #expect(context.output.lines == ["{\"error\":\"Bluetooth is not supported on this device\"}"])
    }

    @Test("No matches in JSON mode emits a JSON error line", .cli())
    func noMatchesJson() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])

        await #expect(throws: ExitCode.failure) {
            try await self.run(["nope", "--json"])
        }
        #expect(context.output.lines == ["{\"error\":\"No matching devices found\"}"])
    }

    @Test("On a terminal the spinners report scan and read progress", .cli(isTerminal: true))
    func spinnersOnTerminal() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])
        context.client.readResults[self.first.id] = .success(ReadingFixtures.aranet4())

        try await self.run(["1A2B3"])

        #expect(context.output.contains("\u{2713}\u{001B}[0m Found Aranet4 1A2B3") == true)
        #expect(context.output.contains("\u{2713}\u{001B}[0m Read complete") == true)
        #expect(context.output.contains("CO2:          812 ppm") == true)
    }

    @Test("On a terminal a scan failure and an empty match mark the spinner as failed", .cli(isTerminal: true))
    func spinnerFailures() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])

        await #expect(throws: ExitCode.failure) {
            try await self.run(["nope"])
        }
        #expect(context.output.contains("\u{2717}\u{001B}[0m No devices found") == true)

        context.client.scanResult = .failure(AranetError.timeout)
        await #expect(throws: ExitCode.failure) {
            try await self.run(["1A2B3"])
        }
        #expect(context.output.contains("\u{2717}\u{001B}[0m Scan failed") == true)
    }
}
