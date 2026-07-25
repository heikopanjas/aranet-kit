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
      } else {
        notFound.append(query)
      }
    }
    return (matched, notFound)
  }
}

// MARK: - Shared Helpers

private func printError(_ error: Error, device: AranetDevice) {
  if let aranetError = error as? AranetError {
    print("Error (\(device.name)): \(aranetError.description)")
  } else {
    print("Error (\(device.name)): \(error.localizedDescription)")
  }
}

/// Performs a BLE scan, matches queries against discovered devices, and manages spinner UI.
private func scanAndMatchDevices(
  queries: [String],
  verbose: Bool
) async throws -> (client: AranetClient, matched: [AranetDevice], notFound: [String]) {
  let scanLabel =
    queries.count == 1
    ? "Scanning for device '\(queries[0])'..."
    : "Scanning for \(queries.count) devices..."
  let spinner = await ProgressSpinner(message: scanLabel)

  if verbose == false {
    await spinner.start()
  } else {
    print(scanLabel)
  }

  let client = AranetClient()
  client.verbose = verbose

  let discoveredDevices: [AranetDevice]
  do {
    discoveredDevices = try await client.scan(timeout: 15.0)
  } catch {
    if verbose == false {
      await spinner.fail(message: "Scan failed")
    }
    if let aranetError = error as? AranetError {
      print("Error: \(aranetError.description)")
      throw ExitCode.failure
    }
    throw error
  }

  let (matched, notFound) = discoveredDevices.match(queries: queries)

  if matched.isEmpty {
    if verbose == false {
      await spinner.fail(message: "No devices found")
    }
    print("Error: No matching devices found")
    throw ExitCode.failure
  }

  let foundLabel = matched.map(\.name).joined(separator: ", ")
  if verbose == false {
    await spinner.succeed(message: "Found \(foundLabel)")
  }

  return (client, matched, notFound)
}

// MARK: - CLI Commands

@main
struct AranetCli: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "aranet-cli",
    abstract: "Command-line tool for Aranet Bluetooth sensors",
    version: "3.3.0",
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
    var timeout: Double = 15.0

    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false

    mutating func run() async throws {
      let spinner = await ProgressSpinner(message: "Scanning for Aranet devices...")

      if verbose == false {
        await spinner.start()
      } else {
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
        } else {
          print("Found \(devices.count) device(s):\n")
          for (index, device) in devices.enumerated() {
            print("\(index + 1). \(device.name) (\(device.id.uuidString))")
          }
        }
      } catch let error as AranetError {
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
      let (client, matched, notFound) = try await scanAndMatchDevices(
        queries: devices, verbose: verbose
      )

      let readLabel =
        matched.count == 1
        ? "Reading from \(matched[0].name)..."
        : "Reading from \(matched.count) devices..."
      let readSpinner = await ProgressSpinner(message: readLabel)
      if verbose == false {
        await readSpinner.start()
      } else {
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
            } catch {
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
          printError(error, device: device)
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
      let (client, matched, notFound) = try await scanAndMatchDevices(
        queries: devices, verbose: verbose
      )

      for name in notFound {
        print("Warning: Device '\(name)' not found")
      }

      print("\nMonitoring started. Press Ctrl+C to stop.\n")

      do {
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
                  printError(error, device: device)
                  throw error
                }
              }
            }
          }

          try await group.next()
          group.cancelAll()
        }

        print("Monitoring stopped.")
      } catch is CancellationError {
        print("\nMonitoring stopped.")
        throw ExitCode.success
      }
    }
  }
}
