import Foundation

// MARK: - Device Types

public enum AranetDeviceType: UInt8, Sendable {
    case aranet4 = 0
    case aranet2 = 1
    case aranetRadiation = 2
    case aranetRadon = 3
    case unknown = 255

    public var name: String {
        switch self {
            case .aranet4:
                return "Aranet4"
            case .aranet2:
                return "Aranet2"
            case .aranetRadiation:
                return "Aranet Radiation"
            case .aranetRadon:
                return "Aranet Radon Plus"
            case .unknown:
                return "Unknown Aranet Device"
        }
    }
}

// MARK: - Status Colors

public enum AranetStatusColor: UInt8, Sendable {
    case error = 0
    case green = 1
    case yellow = 2
    case red = 3

    public var name: String {
        switch self {
            case .error:
                return "ERROR"
            case .green:
                return "GREEN"
            case .yellow:
                return "YELLOW"
            case .red:
                return "RED"
        }
    }
}

// MARK: - Status Alerts

public enum AranetStatus: UInt8, Sendable {
    case off = 0
    case under = 1
    case over = 2
    case dash = 3

    public var name: String {
        switch self {
            case .off:
                return "OFF"
            case .under:
                return "UNDER"
            case .over:
                return "OVER"
            case .dash:
                return "DASH"
        }
    }
}

// MARK: - Current Reading

public struct AranetReading: Sendable {
    public let deviceType: AranetDeviceType
    public let name: String
    public let version: String

    // Aranet2, Aranet4
    public let temperature: Double?
    public let humidity: UInt8?

    // Aranet4
    public let co2: UInt16?
    public let pressure: Double?

    // Aranet Radiation
    public let radiationRate: Double?
    public let radiationTotal: Double?
    public let radiationDuration: UInt64?

    // Aranet Radon
    public let radonConcentration: UInt32?

    // Common
    public let battery: UInt8
    public let status: AranetStatusColor?
    public let interval: UInt16?
    public let ago: UInt16?

    public init(
        deviceType: AranetDeviceType = .unknown,
        name: String = "",
        version: String = "",
        temperature: Double? = nil,
        humidity: UInt8? = nil,
        co2: UInt16? = nil,
        pressure: Double? = nil,
        radiationRate: Double? = nil,
        radiationTotal: Double? = nil,
        radiationDuration: UInt64? = nil,
        radonConcentration: UInt32? = nil,
        battery: UInt8 = 0,
        status: AranetStatusColor? = nil,
        interval: UInt16? = nil,
        ago: UInt16? = nil
    ) {
        self.deviceType = deviceType
        self.name = name
        self.version = version
        self.temperature = temperature
        self.humidity = humidity
        self.co2 = co2
        self.pressure = pressure
        self.radiationRate = radiationRate
        self.radiationTotal = radiationTotal
        self.radiationDuration = radiationDuration
        self.radonConcentration = radonConcentration
        self.battery = battery
        self.status = status
        self.interval = interval
        self.ago = ago
    }

    public func formatOutput() -> String {
        var output = "---------------------------------------\n"
        output += "Connected: \(name)"
        if !version.isEmpty {
            // Add 'v' prefix only if version doesn't already start with 'v'
            let versionString = version.hasPrefix("v") ? version : "v\(version)"
            output += " | \(versionString)"
        }
        output += "\n"

        if let ago = ago, let interval = interval {
            output += "Updated \(ago) s ago. Intervals: \(interval) s\n"
        }

        output += "---------------------------------------\n"

        switch deviceType {
            case .aranet4:
                if let co2 = co2 {
                    output += "CO2:          \(co2) ppm\n"
                }
                if let temperature = temperature {
                    output += String(format: "Temperature:  %.1f °C\n", temperature)
                }
                if let humidity = humidity {
                    output += "Humidity:     \(humidity) %\n"
                }
                if let pressure = pressure {
                    output += String(format: "Pressure:     %.1f hPa\n", pressure)
                }
                output += "Battery:      \(battery) %\n"
                if let status = status {
                    output += "Status Display: \(status.name)\n"
                }
                if let ago = ago, let interval = interval {
                    output += "Age:          \(ago)/\(interval) s\n"
                }

            case .aranet2:
                if let temperature = temperature {
                    output += String(format: "Temperature:  %.1f °C\n", temperature)
                }
                if let humidity = humidity {
                    output += "Humidity:     \(humidity) %\n"
                }
                output += "Battery:      \(battery) %\n"
                if let ago = ago, let interval = interval {
                    output += "Age:          \(ago)/\(interval) s\n"
                }

            case .aranetRadiation:
                if let radiationRate = radiationRate {
                    output += String(format: "Dose rate:    %.2f µSv/h\n", radiationRate / 1000.0)
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

                    output += String(format: "Dose total:   %.4f mSv/%@\n", radiationTotal / 1_000_000.0, durationStr)
                }
                output += "Battery:      \(battery) %\n"
                if let ago = ago, let interval = interval {
                    output += "Age:          \(ago)/\(interval) s\n"
                }

            case .aranetRadon:
                if let radonConcentration = radonConcentration {
                    output += "Radon Conc.:  \(radonConcentration) Bq/m³\n"
                }
                if let temperature = temperature {
                    output += String(format: "Temperature:  %.1f °C\n", temperature)
                }
                if let humidity = humidity {
                    output += "Humidity:     \(humidity) %\n"
                }
                if let pressure = pressure {
                    output += String(format: "Pressure:     %.1f hPa\n", pressure)
                }
                output += "Battery:      \(battery) %\n"
                if let status = status {
                    output += "Status Display: \(status.name)\n"
                }
                if let ago = ago, let interval = interval {
                    output += "Age:          \(ago)/\(interval) s\n"
                }

            case .unknown:
                output += "Unknown device type\n"
        }

        output += "---------------------------------------"
        return output
    }
}
