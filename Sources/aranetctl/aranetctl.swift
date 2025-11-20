// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation

@main
struct AranetCTL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aranetctl",
        abstract: "Command-line tool for Aranet Bluetooth sensors",
        version: "0.1.0",
        subcommands: [Scan.self, Read.self]
    )
}

// MARK: - Scan Command

extension AranetCTL {
    struct Scan: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Scan for nearby Aranet devices"
        )

        @Option(name: .shortAndLong, help: "Scan timeout in seconds")
        var timeout: Double = 5.0

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func run() async throws {
            print("Scanning for Aranet devices...")

            do {
                let client = AranetClient()
                client.verbose = verbose
                let devices = try await client.scan(timeout: timeout)

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
                print("Error: \(error.description)")
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Read Command

extension AranetCTL {
    struct Read: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Read current sensor values from an Aranet device"
        )

        @Argument(help: "Device UUID or name")
        var device: String

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func run() async throws {
            print("Scanning for device '\(device)'...")

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
                    print("Error: Device not found")
                    throw ExitCode.failure
                }

                print("Connecting to \(peripheral.name ?? "device")...")

                if verbose {
                    print("[DEBUG] Starting read operation...")
                }

                let reading = try await client.readCurrentReadings(from: peripheral)
                print(reading.formatOutput())
            }
            catch let error as AranetError {
                print("Error: \(error.description)")
                throw ExitCode.failure
            }
        }
    }
}
