import AranetKit
import Foundation
import Testing

@testable import AranetCli

@Suite(.tags(.cli, .formatting))
struct JsonOutputTests {
    private static let timestamp: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 22
        components.hour = 10
        components.minute = 0
        components.second = 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func measurement(_ object: [String: Any], _ key: String) -> [String: Any]? {
        return object[key] as? [String: Any]
    }

    @Test("Devices encode their identifier and name")
    func deviceEncoding() throws -> Void {
        let id = UUID()
        let object = try self.encode(JsonDevice(AranetDevice(id: id, name: "Aranet4 1A2B3")))

        #expect(object["id"] as? String == id.uuidString)
        #expect(object["name"] as? String == "Aranet4 1A2B3")
        #expect(object.count == 2)
    }

    @Test("Aranet4 readings encode every measurement as a value and unit pair")
    func aranet4ReadingEncoding() throws -> Void {
        let object = try self.encode(JsonReading(ReadingFixtures.aranet4(), timestamp: Self.timestamp))

        #expect(object["device"] as? String == "Aranet4 1A2B3")
        #expect(object["deviceType"] as? String == "Aranet4")
        #expect(object["firmwareVersion"] as? String == "v1.4.14")
        #expect(object["status"] as? String == "GREEN")
        #expect(object["timestamp"] as? String == "2026-10-22T10:00:00Z")
        #expect(self.measurement(object, "battery")?["value"] as? Int == 87)
        #expect(self.measurement(object, "battery")?["unit"] as? String == "percent")
        #expect(self.measurement(object, "co2")?["value"] as? Int == 812)
        #expect(self.measurement(object, "co2")?["unit"] as? String == "ppm")
        #expect(self.measurement(object, "temperature")?["value"] as? Double == 21.5)
        #expect(self.measurement(object, "temperature")?["unit"] as? String == "C")
        #expect(self.measurement(object, "pressure")?["value"] as? Double == 1013.2)
        #expect(self.measurement(object, "pressure")?["unit"] as? String == "hPa")
        #expect(self.measurement(object, "humidity")?["value"] as? Int == 43)
        #expect(self.measurement(object, "interval")?["value"] as? Int == 300)
        #expect(self.measurement(object, "interval")?["unit"] as? String == "seconds")
        #expect(self.measurement(object, "age")?["value"] as? Int == 42)
        #expect(object["radiationRate"] == nil)
        #expect(object["radiationTotal"] == nil)
        #expect(object["radiationDuration"] == nil)
        #expect(object["radonConcentration"] == nil)
    }

    @Test("Radiation readings convert to microsieverts")
    func radiationReadingEncoding() throws -> Void {
        let object = try self.encode(JsonReading(ReadingFixtures.radiation(), timestamp: Self.timestamp))
        let rate = try #require(self.measurement(object, "radiationRate")?["value"] as? Double)
        let total = try #require(self.measurement(object, "radiationTotal")?["value"] as? Double)

        #expect(isApproximately(rate, 0.12))
        #expect(self.measurement(object, "radiationRate")?["unit"] as? String == "\u{00B5}Sv/h")
        #expect(isApproximately(total, 1_234.567))
        #expect(self.measurement(object, "radiationTotal")?["unit"] as? String == "\u{00B5}Sv")
        #expect(self.measurement(object, "radiationDuration")?["value"] as? Int == 90_061)
        #expect(object["co2"] == nil)
        #expect(object["temperature"] == nil)
    }

    @Test("Radon readings keep becquerels per cubic meter")
    func radonReadingEncoding() throws -> Void {
        let object = try self.encode(JsonReading(ReadingFixtures.radon(), timestamp: Self.timestamp))

        #expect(self.measurement(object, "radonConcentration")?["value"] as? Double == 148)
        #expect(self.measurement(object, "radonConcentration")?["unit"] as? String == "Bq/m\u{00B3}")
        #expect(object["status"] as? String == "YELLOW")
    }

    @Test("Empty firmware versions and missing status are omitted")
    func optionalFieldsAreOmitted() throws -> Void {
        let reading = ReadingFixtures.aranet4(status: nil, interval: nil, ago: nil, version: "")
        let object = try self.encode(JsonReading(reading, timestamp: Self.timestamp))

        #expect(object["firmwareVersion"] == nil)
        #expect(object["status"] == nil)
        #expect(object["interval"] == nil)
        #expect(object["age"] == nil)
    }

    @Test("The default timestamp is the current time")
    func defaultTimestampIsNow() -> Void {
        let before = Date()
        let reading = JsonReading(ReadingFixtures.aranet2())

        #expect(reading.timestamp >= before)
        #expect(reading.timestamp <= Date())
    }

    @Test("Errors encode the message and the optional device")
    func errorEncoding() throws -> Void {
        let withDevice = try self.encode(JsonError(error: "Device not found", device: "Aranet4 1A2B3"))
        let withoutDevice = try self.encode(JsonError(error: "Bluetooth is unavailable or not ready", device: nil))

        #expect(withDevice["error"] as? String == "Device not found")
        #expect(withDevice["device"] as? String == "Aranet4 1A2B3")
        #expect(withoutDevice["error"] as? String == "Bluetooth is unavailable or not ready")
        #expect(withoutDevice["device"] == nil)
    }
}
