//
// aranetctl.swift
// aranetctl
//
// Swift reimplementation of the Python aranet4 library
// Based on https://github.com/Anrijs/Aranet4-Python
//
// Copyright (c) 2022 Anrijs Jargans (original Python implementation)
// Copyright (c) 2025 Heiko Panjas (Swift reimplementation)
//
// SPDX-License-Identifier: MIT
//

import AranetKit
import ArgumentParser
import Foundation

// MARK: - Terminal Formatting

extension AranetReading {

    // MARK: - Formatting Helpers

    private var co2Line: String {
        guard let co2 = co2 else { return "" }
        return "CO2:          \(co2) ppm\n"
    }

    private var temperatureLine: String {
        guard let temperature = temperature else { return "" }
        return String(format: "Temperature:  %.1f °C\n", temperature.value)
    }

    private var humidityLine: String {
        guard let humidity = humidity else { return "" }
        return "Humidity:     \(humidity) %\n"
    }

    private var pressureLine: String {
        guard let pressure = pressure else { return "" }
        return String(format: "Pressure:     %.1f hPa\n", pressure.value)
    }

    private var batteryLine: String {
        "Battery:      \(battery) %\n"
    }

    private var statusLine: String {
        guard let status = status else { return "" }
        return "Status Display: \(status.name)\n"
    }

    private var ageLine: String {
        guard let ago = ago, let interval = interval else { return "" }
        return "Age:          \(ago)s/\(interval)s\n"
    }

    private var radonLine: String {
        guard let radonConcentration = radonConcentration else { return "" }
        return String(format: "Radon Conc.:  %.0f Bq/m³\n", radonConcentration.value)
    }

    private var radiationLines: String {
        var result = ""
        if let radiationRate = radiationRate {
            let microSvPerHour = radiationRate.converted(to: .microsieverts)
            result += String(format: "Dose rate:    %.2f µSv/h\n", microSvPerHour.value)
        }
        if let radiationTotal = radiationTotal, let radiationDuration = radiationDuration {
            let seconds = Int(radiationDuration)
            let minutes = (seconds / 60) % 60
            let hours = (seconds / 3600) % 24
            let days = seconds / 86400

            var durationStr = "\(minutes)m"
            if hours > 0 {
                durationStr = "\(hours)h \(durationStr)"
            }
            if days > 0 {
                durationStr = "\(days)d \(durationStr)"
            }

            let milliSv = radiationTotal.converted(to: .millisieverts)
            result += String(format: "Dose total:   %.4f mSv/%@\n", milliSv.value, durationStr)
        }
        return result
    }

    // MARK: - Terminal Output

    /// Formats the sensor reading as a human-readable string for terminal display.
    ///
    /// The output format varies based on device type, showing only relevant measurements
    /// for each specific Aranet model.
    ///
    /// - Returns: Multi-line formatted string with measurement values and units
    func formatOutput() -> String {
        let separator = "---------------------------------------\n"
        var output = separator
        output += "Connected: \(name)"
        if version.isEmpty == false {
            let versionString = version.hasPrefix("v") ? version : "v\(version)"
            output += " | \(versionString)"
        }
        output += "\n"

        if let ago = ago, let interval = interval {
            output += "Updated \(ago)s ago. Intervals: \(interval)s\n"
        }

        output += separator

        switch deviceType {
            case .aranet4:
                output += co2Line + temperatureLine + humidityLine + pressureLine
                output += batteryLine + statusLine + ageLine

            case .aranet2:
                output += temperatureLine + humidityLine
                output += batteryLine + ageLine

            case .aranetRadiation:
                output += radiationLines
                output += batteryLine + statusLine + ageLine

            case .aranetRadon:
                output += radonLine + temperatureLine + humidityLine + pressureLine
                output += batteryLine + statusLine + ageLine

            case .unknown:
                output += "Unknown device type\n"
        }

        output += "---------------------------------------"
        return output
    }
}

// MARK: - Device Matching

extension Array where Element == AranetDevice {
    /// Matches device queries against discovered devices by UUID or name substring.
    func match(queries: [String]) -> (matched: [AranetDevice], notFound: [String]) {
        var matched: [AranetDevice] = []
        var notFound: [String] = []
        for query in queries {
            let queryLower = query.lowercased()
            if let found = first(where: {
                $0.id.uuidString.lowercased() == queryLower
                    || $0.name.lowercased().contains(queryLower)
            }) {
                if matched.contains(where: { $0.id == found.id }) == false {
                    matched.append(found)
                }
            }
            else {
                notFound.append(query)
            }
        }
        return (matched, notFound)
    }
}

// MARK: - Global Options

/// Options shared by every subcommand.
struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false

    /// Hidden copy of the root-level `--json` flag.
    ///
    /// The visible declaration lives on the root command, but swift-argument-parser
    /// does not pass parent values to subcommands, so this keeps
    /// `aranet-cli <subcommand> ... --json` parseable without listing the flag twice
    /// in the help pages.
    @Flag(name: .customLong("json"), help: .hidden)
    var jsonFlag: Bool = false

    /// True when `--json` was given before or after the subcommand name.
    var json: Bool {
        jsonFlag == true || AranetCli.jsonRequested == true
    }

    /// Library diagnostics are suppressed in JSON mode to keep stdout parseable.
    var clientVerbose: Bool {
        json == false && verbose == true
    }

    /// Spinners are only useful on an interactive, non-verbose terminal.
    var showSpinner: Bool {
        json == false && verbose == false
    }

    /// Human-readable status text is suppressed in JSON mode.
    var showStatusText: Bool {
        json == false
    }
}

// MARK: - Shared Helpers

private func printError(_ error: Error, device: AranetDevice, options: GlobalOptions) {
    guard options.json == false else {
        JsonOutput.emitError(error, device: device.name)
        return
    }

    if let aranetError = error as? AranetError {
        print("Error (\(device.name)): \(aranetError.description)")
    }
    else {
        print("Error (\(device.name)): \(error.localizedDescription)")
    }
}

private func printError(_ message: String, options: GlobalOptions) {
    guard options.json == false else {
        JsonOutput.emitError(message)
        return
    }

    print("Error: \(message)")
}

/// Performs a BLE scan, matches queries against discovered devices, and manages spinner UI.
private func scanAndMatchDevices(
    queries: [String],
    options: GlobalOptions
) async throws -> (client: AranetClient, matched: [AranetDevice], notFound: [String]) {
    let scanLabel =
        queries.count == 1
        ? "Scanning for device '\(queries[0])'..."
        : "Scanning for \(queries.count) devices..."
    let spinner = await ProgressSpinner(message: scanLabel)

    if options.showSpinner == true {
        await spinner.start()
    }
    else if options.showStatusText == true {
        print(scanLabel)
    }

    let client = AranetClient()
    client.verbose = options.clientVerbose

    let discoveredDevices: [AranetDevice]
    do {
        discoveredDevices = try await client.scan(timeout: 15.0)
    }
    catch {
        if options.showSpinner == true {
            await spinner.fail(message: "Scan failed")
        }
        if let aranetError = error as? AranetError {
            printError(aranetError.description, options: options)
            throw ExitCode.failure
        }
        throw error
    }

    let (matched, notFound) = discoveredDevices.match(queries: queries)

    if matched.isEmpty {
        if options.showSpinner == true {
            await spinner.fail(message: "No devices found")
        }
        printError("No matching devices found", options: options)
        throw ExitCode.failure
    }

    let foundLabel = matched.map(\.name).joined(separator: ", ")
    if options.showSpinner == true {
        await spinner.succeed(message: "Found \(foundLabel)")
    }

    return (client, matched, notFound)
}

// MARK: - CLI Commands

/// Entry point that reports parsing and runtime failures as JSON when `--json` is used.
///
/// `ArgumentParser` writes its own plain-text diagnostics for anything thrown out of a
/// command, which scripts and agents cannot parse, so errors are intercepted here.
@main
enum AranetCliMain {
    static func main() async {
        do {
            var command = try AranetCli.parseAsRoot()

            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            }
            else {
                try command.run()
            }
        }
        catch {
            exit(withError: error)
        }
    }

    private static func exit(withError error: Error) -> Never {
        guard AranetCli.jsonRequested == true else {
            AranetCli.exit(withError: error)
        }

        let exitCode = AranetCli.exitCode(for: error)

        // Help and version requests are not failures and keep their regular output.
        guard exitCode != ExitCode.success else {
            AranetCli.exit(withError: error)
        }

        let message = AranetCli.message(for: error)
        if message.isEmpty == false {
            JsonOutput.emitError(message)
        }

        AranetCli.exit(withError: exitCode)
    }
}

struct AranetCli: AsyncParsableCommand {
    /// Current tool version, reported by the root-level `--version` flag.
    static let toolVersion = "3.5.2"

    /// True when `--json` appears anywhere on the command line.
    ///
    /// Needed because errors are raised before, and after, a command is parsed.
    static var jsonRequested: Bool {
        CommandLine.arguments.contains("--json")
    }

    static let configuration = CommandConfiguration(
        commandName: "aranet-cli",
        abstract: "Command-line tool for Aranet Bluetooth sensors",
        subcommands: [Scan.self, Read.self, Monitor.self]
    )

    @Flag(name: .customLong("version"), help: "Show the version.")
    var showVersion: Bool = false

    @Flag(
        name: .customLong("json"),
        help: "Emit machine-readable JSON only (script and agent mode)"
    )
    var json: Bool = false

    mutating func run() async throws {
        guard showVersion == true else {
            throw CleanExit.helpRequest(self)
        }

        print(Self.toolVersion)
    }
}

// MARK: - Scan Command

extension AranetCli {
    struct Scan: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Scan for nearby Aranet devices"
        )

        @Option(name: .shortAndLong, help: "Scan timeout in seconds")
        var timeout: Double = 15.0

        @OptionGroup var options: GlobalOptions

        mutating func run() async throws {
            let spinner = await ProgressSpinner(message: "Scanning for Aranet devices...")

            if options.showSpinner == true {
                await spinner.start()
            }
            else if options.showStatusText == true {
                print("Scanning for Aranet devices...")
            }

            do {
                let client = AranetClient()
                client.verbose = options.clientVerbose
                let devices = try await client.scan(timeout: timeout)

                if options.showSpinner == true {
                    await spinner.stop()
                }

                guard options.json == false else {
                    JsonOutput.emit(devices.map(JsonDevice.init))
                    return
                }

                if devices.isEmpty {
                    print("No devices found.")
                }
                else {
                    print("Found \(devices.count) device(s):\n")
                    for (index, device) in devices.enumerated() {
                        print("\(index + 1). \(device.name) (\(device.id.uuidString))")
                    }
                }
            }
            catch let error as AranetError {
                if options.showSpinner == true {
                    await spinner.fail(message: "Scan failed")
                }
                printError(error.description, options: options)
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Read Command

extension AranetCli {
    struct Read: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Read current sensor values from one or more Aranet devices"
        )

        @Argument(help: "Device UUID(s) or name(s) to read from")
        var devices: [String]

        @OptionGroup var options: GlobalOptions

        mutating func run() async throws {
            let (client, matched, notFound) = try await scanAndMatchDevices(
                queries: devices, options: options
            )

            let readLabel =
                matched.count == 1
                ? "Reading from \(matched[0].name)..."
                : "Reading from \(matched.count) devices..."
            let readSpinner = await ProgressSpinner(message: readLabel)
            if options.showSpinner == true {
                await readSpinner.start()
            }
            else if options.showStatusText == true {
                print(readLabel)
            }

            let readings: [(AranetDevice, Result<AranetReading, Error>)] = await withTaskGroup(
                of: (AranetDevice, Result<AranetReading, Error>).self,
                returning: [(AranetDevice, Result<AranetReading, Error>)].self
            ) { group in
                for device in matched {
                    group.addTask {
                        do {
                            let reading = try await client.readCurrentReadings(from: device)
                            return (device, .success(reading))
                        }
                        catch {
                            return (device, .failure(error))
                        }
                    }
                }

                var results: [(AranetDevice, Result<AranetReading, Error>)] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }

            if options.showSpinner == true {
                await readSpinner.succeed(message: "Read complete")
            }

            var hadError = false
            var successfulReadings: [JsonReading] = []
            var failures: [(device: AranetDevice, error: Error)] = []
            for (device, result) in readings {
                switch result {
                    case .success(let reading):
                        if options.json == true {
                            successfulReadings.append(JsonReading(reading))
                        }
                        else {
                            print(reading.formatOutput())
                        }
                    case .failure(let error):
                        failures.append((device, error))
                }
            }

            if options.json == true {
                JsonOutput.emit(successfulReadings)
            }

            for failure in failures {
                hadError = true
                printError(failure.error, device: failure.device, options: options)
            }

            for name in notFound {
                hadError = true
                printError("Device '\(name)' not found", options: options)
            }

            if hadError == true {
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Monitor Command

extension AranetCli {
    struct Monitor: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Monitor sensor values from one or more Aranet devices with periodic updates"
        )

        @Argument(help: "Device UUID(s) or name(s) to monitor")
        var devices: [String]

        @OptionGroup var options: GlobalOptions

        mutating func run() async throws {
            let options = self.options
            let (client, matched, notFound) = try await scanAndMatchDevices(
                queries: devices, options: options
            )

            for name in notFound {
                if options.json == true {
                    JsonOutput.emitError("Device '\(name)' not found", device: name)
                }
                else {
                    print("Warning: Device '\(name)' not found")
                }
            }

            if options.showStatusText == true {
                print("\nMonitoring started. Press Ctrl+C to stop.\n")
            }

            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for device in matched {
                        group.addTask {
                            let stream = await client.monitor(from: device)
                            for await result in stream {
                                switch result {
                                    case .success(let reading):
                                        if options.json == true {
                                            JsonOutput.emit(JsonReading(reading), pretty: false)
                                        }
                                        else {
                                            print("\(Date())")
                                            print(reading.formatOutput())
                                            print()
                                        }

                                    case .failure(let error):
                                        printError(error, device: device, options: options)
                                        throw ExitCode.failure
                                }
                            }
                        }
                    }

                    try await group.next()
                    group.cancelAll()
                }

                if options.showStatusText == true {
                    print("Monitoring stopped.")
                }
            }
            catch is CancellationError {
                if options.showStatusText == true {
                    print("\nMonitoring stopped.")
                }
                throw ExitCode.success
            }
        }
    }
}
