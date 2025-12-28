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
        version: "2.0.0",
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
                        print("\(index + 1). \(device.name ?? "Unknown") (\(device.identifier.uuidString))")
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
            abstract: "Read current sensor values from an Aranet device"
        )

        @Argument(help: "Device UUID or name")
        var device: String

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func run() async throws {
            let scanSpinner = await ProgressSpinner(message: "Scanning for device '\(device)'...")

            if verbose == false {
                await scanSpinner.start()
            }
            else {
                print("Scanning for device '\(device)'...")
            }

            do {
                let client = AranetClient()
                client.verbose = verbose
                let devices = try await client.scan(timeout: 10.0)

                guard
                    let peripheral = devices.first(where: {
                        $0.identifier.uuidString.lowercased() == device.lowercased()
                            || $0.name?.lowercased().contains(device.lowercased()) == true
                    })
                else {
                    if verbose == false {
                        await scanSpinner.fail(message: "Device not found")
                    }
                    print("Error: Device not found")
                    throw ExitCode.failure
                }

                if verbose == false {
                    await scanSpinner.succeed(message: "Found \(peripheral.name ?? "device")")
                }

                let connectSpinner = await ProgressSpinner(message: "Connecting to \(peripheral.name ?? "device")...")
                if verbose == false {
                    await connectSpinner.start()
                }
                else {
                    print("Connecting to \(peripheral.name ?? "device")...")
                }

                if verbose == true {
                    print("[DEBUG] Starting read operation...")
                }

                let reading = try await client.readCurrentReadings(from: peripheral)

                if verbose == false {
                    await connectSpinner.succeed(message: "Connected to \(peripheral.name ?? "device")")
                }

                print(reading.formatOutput())
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
            abstract: "Monitor sensor values from an Aranet device with periodic updates"
        )

        @Argument(help: "Device UUID or name")
        var device: String

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func run() async throws {
            let scanSpinner = await ProgressSpinner(message: "Scanning for device '\(device)'...")

            if verbose == false {
                await scanSpinner.start()
            }
            else {
                print("Scanning for device '\(device)'...")
            }

            let client = AranetClient()
            client.verbose = verbose

            do {
                let devices = try await client.scan(timeout: 10.0)

                guard
                    let peripheral = devices.first(where: {
                        $0.identifier.uuidString.lowercased() == device.lowercased()
                            || $0.name?.lowercased().contains(device.lowercased()) == true
                    })
                else {
                    if verbose == false {
                        await scanSpinner.fail(message: "Device not found")
                    }
                    print("Error: Device not found")
                    throw ExitCode.failure
                }

                if verbose == false {
                    await scanSpinner.succeed(message: "Found \(peripheral.name ?? "device")")
                }

                print("\nMonitoring started. Press Ctrl+C to stop.\n")

                // Use the monitoring stream from the library
                let monitorStream = await client.monitor(from: peripheral)

                for await result in monitorStream {
                    switch result {
                        case .success(let reading):
                            print("\(Date())")
                            print(reading.formatOutput())
                            print()

                        case .failure(let error):
                            if let aranetError = error as? AranetError {
                                print("Error: \(aranetError.description)")
                            }
                            else {
                                print("Error: \(error.localizedDescription)")
                            }
                            throw ExitCode.failure
                    }
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
