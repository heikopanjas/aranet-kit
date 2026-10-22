//
// ReadCommand.swift
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
    struct Read: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Read current sensor values from one or more Aranet devices"
        )

        @Argument(help: "Device UUID(s) or name(s) to read from")
        var devices: [String]

        @OptionGroup var options: GlobalOptions

        mutating func run() async throws -> Void {
            let environment = CliEnvironment.current
            let options = self.options
            let scan = try await DeviceScanner.scanAndMatch(queries: self.devices, options: options)
            let matched = scan.match.matched

            let readLabel =
                matched.count == 1
                ? "Reading from \(matched[0].name)..."
                : "Reading from \(matched.count) devices..."
            let spinner = await ProgressSpinner(message: readLabel)
            if options.showSpinner == true {
                await spinner.start()
            }
            else if options.showStatusText == true {
                environment.printLine(readLabel)
            }

            let outcomes = await Self.readAll(matched, with: scan.client)

            if options.showSpinner == true {
                await spinner.succeed(message: "Read complete")
            }

            var readings: [JsonReading] = []
            var failures: [ReadOutcome] = []
            for outcome in outcomes {
                switch outcome.result {
                    case .success(let reading):
                        if options.json == true {
                            readings.append(JsonReading(reading, timestamp: environment.now()))
                        }
                        else {
                            environment.printLine(reading.formatOutput())
                        }
                    case .failure:
                        failures.append(outcome)
                }
            }

            if options.json == true {
                try JsonOutput.emit(readings)
            }

            for failure in failures {
                if case .failure(let error) = failure.result {
                    ErrorPrinter.print(error, device: failure.device, json: options.json)
                }
            }

            for name in scan.match.notFound {
                ErrorPrinter.print("Device '\(name)' not found", json: options.json)
            }

            if failures.isEmpty == false || scan.match.notFound.isEmpty == false {
                throw ExitCode.failure
            }
        }

        /// Reads every device concurrently and returns the outcomes in the order the devices were given.
        private static func readAll(_ devices: [AranetDevice], with client: any SensorClient) async -> [ReadOutcome] {
            let outcomes = await withTaskGroup(of: ReadOutcome.self, returning: [ReadOutcome].self) { group in
                for device in devices {
                    group.addTask {
                        do {
                            let reading = try await client.readCurrentReadings(from: device)
                            return ReadOutcome(device: device, result: .success(reading))
                        }
                        catch {
                            return ReadOutcome(device: device, result: .failure(error))
                        }
                    }
                }

                var collected: [ReadOutcome] = []
                for await outcome in group {
                    collected.append(outcome)
                }
                return collected
            }

            return devices.compactMap { device in
                return outcomes.first { $0.device.id == device.id }
            }
        }
    }
}
