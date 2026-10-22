//
// AranetReading+TerminalOutput.swift
// AranetCli
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
import Foundation

extension AranetReading {
    private static let separator = "---------------------------------------"
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3_600
    private static let secondsPerDay = 86_400

    /// Formats the sensor reading as a human-readable string for terminal display.
    ///
    /// The output format varies based on device type, showing only relevant measurements
    /// for each specific Aranet model.
    ///
    /// - Returns: Multi-line formatted string with measurement values and units
    func formatOutput() -> String {
        var output = Self.separator + "\n"
        output += "Connected: \(self.name)"
        if self.version.isEmpty == false {
            let versionString = self.version.hasPrefix("v") == true ? self.version : "v\(self.version)"
            output += " | \(versionString)"
        }
        output += "\n"

        if let ago = self.ago, let interval = self.interval {
            output += "Updated \(ago)s ago. Intervals: \(interval)s\n"
        }

        output += Self.separator + "\n"

        switch self.deviceType {
            case .aranet4:
                output += self.co2Line + self.temperatureLine + self.humidityLine + self.pressureLine
                output += self.batteryLine + self.statusLine + self.ageLine
            case .aranet2:
                output += self.temperatureLine + self.humidityLine
                output += self.batteryLine + self.ageLine
            case .aranetRadiation:
                output += self.radiationLines
                output += self.batteryLine + self.statusLine + self.ageLine
            case .aranetRadon:
                output += self.radonLine + self.temperatureLine + self.humidityLine + self.pressureLine
                output += self.batteryLine + self.statusLine + self.ageLine
            case .unknown:
                output += "Unknown device type\n"
        }

        output += Self.separator
        return output
    }

    // MARK: - Formatting Helpers

    private var co2Line: String {
        guard let co2 = self.co2 else { return "" }
        return "CO2:          \(co2) ppm\n"
    }

    private var temperatureLine: String {
        guard let temperature = self.temperature else { return "" }
        return String(format: "Temperature:  %.1f \u{00B0}C\n", temperature.value)
    }

    private var humidityLine: String {
        guard let humidity = self.humidity else { return "" }
        return "Humidity:     \(humidity) %\n"
    }

    private var pressureLine: String {
        guard let pressure = self.pressure else { return "" }
        return String(format: "Pressure:     %.1f hPa\n", pressure.value)
    }

    private var batteryLine: String {
        return "Battery:      \(self.battery) %\n"
    }

    private var statusLine: String {
        guard let status = self.status else { return "" }
        return "Status Display: \(status.name)\n"
    }

    private var ageLine: String {
        guard let ago = self.ago, let interval = self.interval else { return "" }
        return "Age:          \(ago)s/\(interval)s\n"
    }

    private var radonLine: String {
        guard let radonConcentration = self.radonConcentration else { return "" }
        return String(format: "Radon Conc.:  %.0f Bq/m\u{00B3}\n", radonConcentration.value)
    }

    private var radiationLines: String {
        var result = ""
        if let radiationRate = self.radiationRate {
            let microsievertsPerHour = radiationRate.converted(to: .microsieverts)
            result += String(format: "Dose rate:    %.2f \u{00B5}Sv/h\n", microsievertsPerHour.value)
        }
        if let radiationTotal = self.radiationTotal, let radiationDuration = self.radiationDuration {
            let millisieverts = radiationTotal.converted(to: .millisieverts)
            result += String(format: "Dose total:   %.4f mSv/%@\n", millisieverts.value, Self.durationText(seconds: Int(radiationDuration)))
        }
        return result
    }

    /// Formats a duration as days, hours, and minutes, omitting leading zero units.
    private static func durationText(seconds: Int) -> String {
        let minutes = (seconds / Self.secondsPerMinute) % Self.secondsPerMinute
        let hours = (seconds / Self.secondsPerHour) % 24
        let days = seconds / Self.secondsPerDay

        var text = "\(minutes)m"
        if hours > 0 {
            text = "\(hours)h \(text)"
        }
        if days > 0 {
            text = "\(days)d \(text)"
        }
        return text
    }
}
