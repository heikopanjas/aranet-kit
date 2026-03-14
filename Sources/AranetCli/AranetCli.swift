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
    /// Formats the sensor reading as a human-readable string for terminal display.
    ///
    /// The output format varies based on device type, showing only relevant measurements
    /// for each specific Aranet model.
    ///
    /// - Returns: Multi-line formatted string with measurement values and units
    func formatOutput() -> String {
        var output = "---------------------------------------\n"
        output += "Connected: \(name)"
        if !version.isEmpty {
            // Add 'v' prefix only if version doesn't already start with 'v'
            let versionString = version.hasPrefix("v") ? version : "v\(version)"
            output += " | \(versionString)"
        }
        output += "\n"

        if let ago = ago, let interval = interval {
            output += "Updated \(ago)s ago. Intervals: \(interval)s\n"
        }

        output += "---------------------------------------\n"

        switch deviceType {
            case .aranet4:
                if let co2 = co2 {
                    output += "CO2:          \(co2) ppm\n"
                }
                if let temperature = temperature {
                    output += String(format: "Temperature:  %.1f °C\n", temperature.value)
                }
                if let humidity = humidity {
                    output += "Humidity:     \(humidity) %\n"
                }
                if let pressure = pressure {
                    output += String(format: "Pressure:     %.1f hPa\n", pressure.value)
                }
                output += "Battery:      \(battery) %\n"
                if let status = status {
                    output += "Status Display: \(status.name)\n"
                }
                if let ago = ago, let interval = interval {
                    output += "Age:          \(ago)s/\(interval)s\n"
                }

            case .aranet2:
                if let temperature = temperature {
                    output += String(format: "Temperature:  %.1f °C\n", temperature.value)
                }
                if let humidity = humidity {
                    output += "Humidity:     \(humidity) %\n"
                }
                output += "Battery:      \(battery) %\n"
                if let ago = ago, let interval = interval {
                    output += "Age:          \(ago)s/\(interval)s\n"
                }

            case .aranetRadiation:
                if let radiationRate = radiationRate {
                    let microSvPerHour = radiationRate.converted(to: .microsieverts)
                    output += String(format: "Dose rate:    %.2f µSv/h\n", microSvPerHour.value)
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
                    output +=
                        String(
                            format: "Dose total:   %.4f mSv/%@\n", milliSv.value,
                            durationStr)
                }
                output += "Battery:      \(battery) %\n"
                if let ago = ago, let interval = interval {
                    output += "Age:          \(ago)s/\(interval)s\n"
                }

            case .aranetRadon:
                if let radonConcentration = radonConcentration {
                    output += String(format: "Radon Conc.:  %.0f Bq/m³\n", radonConcentration.value)
                }
                if let temperature = temperature {
                    output += String(format: "Temperature:  %.1f °C\n", temperature.value)
                }
                if let humidity = humidity {
                    output += "Humidity:     \(humidity) %\n"
                }
                if let pressure = pressure {
                    output += String(format: "Pressure:     %.1f hPa\n", pressure.value)
                }
                output += "Battery:      \(battery) %\n"
                if let status = status {
                    output += "Status Display: \(status.name)\n"
                }
                if let ago = ago, let interval = interval {
                    output += "Age:          \(ago)s/\(interval)s\n"
                }

            case .unknown:
                output += "Unknown device type\n"
        }

        output += "---------------------------------------"
        return output
    }
}

// MARK: - CLI Commands

@main
struct AranetCli: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aranetcli",
        abstract: "Command-line tool for Aranet Bluetooth sensors",
        version: "3.1.0",
        subcommands: [Scan.self, Read.self, Monitor.self]
    )
}

// MARK: - Scan Command

extension AranetCli {
    struct Scan: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Scan for nearby Aranet devices"
        )

        @Option(name: .shortAndLong, help: "Scan timeout in seconds")
        var timeout: Double = 10.0

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func run() async throws {
            let spinner = await ProgressSpinner(message: "Scanning for Aranet devices...")

            if verbose == false {
                await spinner.start()
            }
            else {
                print("Scanning for Aranet devices...")
            }

            do {
                let client = AranetClient()
                client.verbose = verbose
                let devices = try await client.scan(timeout: timeout)

                if verbose == false {
                    await spinner.stop()
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
                if verbose == false {
                    await spinner.fail(message: "Scan failed")
                }
                print("Error: \(error.description)")
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

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func run() async throws {
            let scanLabel = devices.count == 1
                ? "Scanning for device '\(devices[0])'..."
                : "Scanning for \(devices.count) devices..."
            let scanSpinner = await ProgressSpinner(message: scanLabel)

            if verbose == false {
                await scanSpinner.start()
            }
            else {
                print(scanLabel)
            }

            do {
                let client = AranetClient()
                client.verbose = verbose
                let discoveredDevices = try await client.scan(timeout: 10.0)

                var matched: [AranetDevice] = []
                var notFound: [String] = []

                for query in devices {
                    let queryLower = query.lowercased()
                    if let found = discoveredDevices.first(where: {
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

                if matched.isEmpty {
                    if verbose == false {
                        await scanSpinner.fail(message: "No devices found")
                    }
                    print("Error: No matching devices found")
                    throw ExitCode.failure
                }

                let foundLabel = matched.map(\.name).joined(separator: ", ")
                if verbose == false {
                    await scanSpinner.succeed(message: "Found \(foundLabel)")
                }

                let readLabel = matched.count == 1
                    ? "Reading from \(matched[0].name)..."
                    : "Reading from \(matched.count) devices..."
                let readSpinner = await ProgressSpinner(message: readLabel)
                if verbose == false {
                    await readSpinner.start()
                }
                else {
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

                if verbose == false {
                    await readSpinner.succeed(message: "Read complete")
                }

                var hadError = false
                for (device, result) in readings {
                    switch result {
                        case .success(let reading):
                            print(reading.formatOutput())
                        case .failure(let error):
                            hadError = true
                            if let aranetError = error as? AranetError {
                                print("Error reading \(device.name): \(aranetError.description)")
                            }
                            else {
                                print("Error reading \(device.name): \(error.localizedDescription)")
                            }
                    }
                }

                for name in notFound {
                    hadError = true
                    print("Error: Device '\(name)' not found")
                }

                if hadError == true {
                    throw ExitCode.failure
                }
            }
            catch let error as AranetError {
                print("Error: \(error.description)")
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

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func run() async throws {
            let scanLabel = devices.count == 1
                ? "Scanning for device '\(devices[0])'..."
                : "Scanning for \(devices.count) devices..."
            let scanSpinner = await ProgressSpinner(message: scanLabel)

            if verbose == false {
                await scanSpinner.start()
            }
            else {
                print(scanLabel)
            }

            let client = AranetClient()
            client.verbose = verbose

            do {
                let discoveredDevices = try await client.scan(timeout: 10.0)

                var matched: [AranetDevice] = []
                var notFound: [String] = []

                for query in devices {
                    let queryLower = query.lowercased()
                    if let found = discoveredDevices.first(where: {
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

                for name in notFound {
                    print("Warning: Device '\(name)' not found")
                }

                if matched.isEmpty {
                    if verbose == false {
                        await scanSpinner.fail(message: "No devices found")
                    }
                    print("Error: No matching devices found")
                    throw ExitCode.failure
                }

                let foundLabel = matched.map(\.name).joined(separator: ", ")
                if verbose == false {
                    await scanSpinner.succeed(message: "Found \(foundLabel)")
                }

                print("\nMonitoring started. Press Ctrl+C to stop.\n")

                try await withThrowingTaskGroup(of: Void.self) { group in
                    for device in matched {
                        group.addTask {
                            let stream = await client.monitor(from: device)
                            for await result in stream {
                                switch result {
                                    case .success(let reading):
                                        print("\(Date())")
                                        print(reading.formatOutput())
                                        print()

                                    case .failure(let error):
                                        if let aranetError = error as? AranetError {
                                            print("Error (\(device.name)): \(aranetError.description)")
                                        }
                                        else {
                                            print("Error (\(device.name)): \(error.localizedDescription)")
                                        }
                                        throw error
                                }
                            }
                        }
                    }

                    try await group.next()
                    group.cancelAll()
                }

                print("Monitoring stopped.")
            }
            catch let error as AranetError {
                print("Error: \(error.description)")
                throw ExitCode.failure
            }
            catch is CancellationError {
                print("\nMonitoring stopped.")
                throw ExitCode.success
            }
        }
    }
}
