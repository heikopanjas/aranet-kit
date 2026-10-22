//
// ScanCommand.swift
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
    struct Scan: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Scan for nearby Aranet devices"
        )

        @OptionGroup var options: GlobalOptions

        mutating func run() async throws -> Void {
            let environment = CliEnvironment.current
            let options = self.options
            let spinner = await ProgressSpinner(message: "Scanning for Aranet devices...")

            if options.showSpinner == true {
                await spinner.start()
            }
            else if options.showStatusText == true {
                environment.printLine("Scanning for Aranet devices...")
            }

            let client = await environment.makeClient()
            let clientVerbose = options.clientVerbose
            await MainActor.run {
                client.verbose = clientVerbose
            }

            let devices: [AranetDevice]
            do {
                devices = try await client.scan(timeout: options.timeout)
            }
            catch {
                if options.showSpinner == true {
                    await spinner.fail(message: "Scan failed")
                }
                ErrorPrinter.print(error.localizedDescription, json: options.json)
                throw ExitCode.failure
            }

            if options.showSpinner == true {
                await spinner.stop()
            }

            guard options.json == false else {
                try JsonOutput.emit(devices.map(JsonDevice.init))
                return
            }

            if devices.isEmpty == true {
                environment.printLine("No devices found.")
                return
            }

            environment.printLine("Found \(devices.count) device(s):\n")
            for (index, device) in devices.enumerated() {
                environment.printLine("\(index + 1). \(device.name) (\(device.id.uuidString))")
            }
        }
    }
}
