//
// DeviceScanner.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

import AranetKit
import ArgumentParser
import Foundation

/// Shared scan step of `read` and `monitor`: scans, matches queries, and manages the spinner.
enum DeviceScanner {
    static func scanAndMatch(queries: [String], options: GlobalOptions) async throws -> ScanResult {
        let environment = CliEnvironment.current
        let scanLabel =
            queries.count == 1
            ? "Scanning for device '\(queries[0])'..."
            : "Scanning for \(queries.count) devices..."
        let spinner = await ProgressSpinner(message: scanLabel)

        if options.showSpinner == true {
            await spinner.start()
        }
        else if options.showStatusText == true {
            environment.printLine(scanLabel)
        }

        let client = await environment.makeClient()
        let clientVerbose = options.clientVerbose
        await MainActor.run {
            client.verbose = clientVerbose
        }

        let discoveredDevices: [AranetDevice]
        do {
            discoveredDevices = try await client.scan(timeout: options.timeout)
        }
        catch {
            if options.showSpinner == true {
                await spinner.fail(message: "Scan failed")
            }
            ErrorPrinter.print(error.localizedDescription, json: options.json)
            throw ExitCode.failure
        }

        let match = discoveredDevices.match(queries: queries)

        if match.matched.isEmpty == true {
            if options.showSpinner == true {
                await spinner.fail(message: "No devices found")
            }
            ErrorPrinter.print("No matching devices found", json: options.json)
            throw ExitCode.failure
        }

        if options.showSpinner == true {
            await spinner.succeed(message: "Found \(match.matched.map(\.name).joined(separator: ", "))")
        }

        return ScanResult(client: client, match: match)
    }
}
