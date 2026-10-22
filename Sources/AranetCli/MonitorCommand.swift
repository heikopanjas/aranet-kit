//
// MonitorCommand.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit
import ArgumentParser
import Foundation

extension AranetCli {
    struct Monitor: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Monitor sensor values from one or more Aranet devices with periodic updates"
        )

        @Argument(help: "Device UUID(s) or name(s) to monitor")
        var devices: [String]

        @OptionGroup var options: GlobalOptions

        /// What ended one child task of the monitoring group.
        private enum Outcome: Sendable {
            case deviceStopped(failed: Bool)
            case interrupted
            case interruptsEnded
        }

        mutating func run() async throws -> Void {
            let environment = CliEnvironment.current
            let options = self.options
            let scan = try await DeviceScanner.scanAndMatch(queries: self.devices, options: options)

            for name in scan.match.notFound {
                if options.json == true {
                    JsonOutput.emitError("Device '\(name)' not found", device: name)
                }
                else {
                    environment.printLine("Warning: Device '\(name)' not found")
                }
            }

            if options.showStatusText == true {
                environment.printLine("\nMonitoring started. Press Ctrl+C to stop.\n")
            }

            let anyFailed = await Self.monitorAll(scan.match.matched, with: scan.client, json: options.json)

            if options.showStatusText == true {
                environment.printLine("Monitoring stopped.")
            }
            if anyFailed == true {
                throw ExitCode.failure
            }
        }

        /// Monitors every device until all of them stop or an interrupt arrives. Returns whether any device failed.
        private static func monitorAll(_ devices: [AranetDevice], with client: any SensorClient, json: Bool) async -> Bool {
            let environment = CliEnvironment.current

            return await withTaskGroup(of: Outcome.self, returning: Bool.self) { group in
                for device in devices {
                    group.addTask {
                        let failed = await Self.monitor(device, with: client, json: json)
                        return .deviceStopped(failed: failed)
                    }
                }
                group.addTask {
                    for await _ in environment.interrupts() {
                        return .interrupted
                    }
                    return .interruptsEnded
                }

                var activeDevices = devices.count
                var anyFailed = false
                while activeDevices > 0, let outcome = await group.next() {
                    switch outcome {
                        case .deviceStopped(let failed):
                            activeDevices -= 1
                            anyFailed = anyFailed || failed
                        case .interrupted:
                            activeDevices = 0
                        case .interruptsEnded:
                            break
                    }
                }

                group.cancelAll()
                return anyFailed
            }
        }

        /// Prints every reading of one device; returns true when the stream ended with a failure.
        private static func monitor(_ device: AranetDevice, with client: any SensorClient, json: Bool) async -> Bool {
            let environment = CliEnvironment.current
            let stream = await client.monitor(from: device)

            for await result in stream {
                switch result {
                    case .success(let reading):
                        if json == true {
                            _ = try? JsonOutput.emit(JsonReading(reading, timestamp: environment.now()), pretty: false)
                        }
                        else {
                            environment.printLine("\(environment.now())")
                            environment.printLine(reading.formatOutput())
                            environment.printLine("")
                        }
                    case .failure(let error):
                        ErrorPrinter.print(error, device: device, json: json)
                        return true
                }
            }
            return false
        }
    }
}
