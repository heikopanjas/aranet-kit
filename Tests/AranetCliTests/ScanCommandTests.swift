import AranetKit
import ArgumentParser
import Foundation
import Testing

@testable import AranetCli

@MainActor
@Suite(.tags(.cli))
struct ScanCommandTests {
    private let first = AranetDevice(id: UUID(), name: "Aranet4 1A2B3")
    private let second = AranetDevice(id: UUID(), name: "Aranet Radiation 7E8F9")

    private func run(_ arguments: [String]) async throws -> Void {
        var command = try AranetCli.Scan.parse(arguments)
        try await command.run()
    }

    @Test("Lists discovered devices with their identifiers", .cli())
    func listsDevices() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first, self.second])

        try await self.run(["--timeout", "3"])

        #expect(context.output.lines[0] == "Scanning for Aranet devices...")
        #expect(context.output.contains("Found 2 device(s):") == true)
        #expect(context.output.contains("1. Aranet4 1A2B3 (\(self.first.id.uuidString))") == true)
        #expect(context.output.contains("2. Aranet Radiation 7E8F9 (\(self.second.id.uuidString))") == true)
        #expect(context.client.scanTimeouts == [3])
        #expect(context.client.verbose == false)
    }

    @Test("Reports when nothing was found", .cli())
    func reportsNoDevices() async throws -> Void {
        let context = try currentContext()

        try await self.run([])

        #expect(context.output.lines == ["Scanning for Aranet devices...", "No devices found."])
        #expect(context.client.scanTimeouts == [15])
    }

    @Test("JSON mode emits only the device array", .cli())
    func jsonMode() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])

        try await self.run(["--json"])

        let object = try JSONSerialization.jsonObject(with: Data(context.output.text.utf8))
        let devices = try #require(object as? [[String: String]])
        #expect(devices == [["id": self.first.id.uuidString, "name": "Aranet4 1A2B3"]])
        #expect(context.output.contains("Scanning") == false)
    }

    @Test("A scan failure prints the error and fails the command", .cli())
    func scanFailure() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .failure(AranetError.bluetoothUnavailable)

        await #expect(throws: ExitCode.failure) {
            try await self.run([])
        }
        #expect(context.output.lines.last == "Error: Bluetooth is unavailable or not ready")
    }

    @Test("A scan failure in JSON mode emits a JSON error line", .cli(arguments: ["--json", "scan"]))
    func scanFailureJson() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .failure(AranetError.bluetoothUnauthorized)

        await #expect(throws: ExitCode.failure) {
            try await self.run([])
        }
        #expect(context.output.lines.count == 1)
        #expect(context.output.contains("\"error\":\"Bluetooth access is not authorized.") == true)
    }

    @Test("Verbose mode is passed to the client", .cli())
    func verboseMode() async throws -> Void {
        let context = try currentContext()

        try await self.run(["--verbose"])

        #expect(context.client.verbose == true)
    }

    @Test("On a terminal the spinner animates and is cleared before the results", .cli(isTerminal: true))
    func spinnerOnTerminal() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .success([self.first])

        try await self.run([])

        #expect(context.output.text.hasPrefix("\u{001B}[?25l") == true, "The cursor is hidden while the spinner runs")
        #expect(context.output.contains("Scanning for Aranet devices...") == true)
        #expect(context.output.contains("\r\u{001B}[K") == true, "The spinner line is cleared")
        #expect(context.output.contains("\u{001B}[?25h") == true, "The cursor is shown again")
        #expect(context.output.contains("Found 1 device(s):") == true)
    }

    @Test("On a terminal a failed scan marks the spinner as failed", .cli(isTerminal: true))
    func spinnerFailure() async throws -> Void {
        let context = try currentContext()
        context.client.scanResult = .failure(AranetError.timeout)

        await #expect(throws: ExitCode.failure) {
            try await self.run([])
        }
        #expect(context.output.contains("\u{2717}\u{001B}[0m Scan failed") == true)
        #expect(context.output.contains("Error: Operation timed out") == true)
    }
}
