import AranetKit
import Foundation
import Testing

@testable import AranetCli

@Suite(.tags(.cli))
struct DeviceMatchingTests {
    private static let firstId = UUID(uuidString: "0B1C2D3E-4F50-6172-8394-A5B6C7D8E9F0") ?? UUID()
    private static let secondId = UUID(uuidString: "1C2D3E4F-5061-7283-94A5-B6C7D8E9F0A1") ?? UUID()
    private static let devices = [
        AranetDevice(id: DeviceMatchingTests.firstId, name: "Aranet4 1A2B3"),
        AranetDevice(id: DeviceMatchingTests.secondId, name: "Aranet Radiation 7E8F9")
    ]

    @Test("Matches a device by its exact identifier in any letter case")
    func matchesByIdentifier() -> Void {
        let lower = Self.devices.match(queries: [Self.firstId.uuidString.lowercased()])
        let upper = Self.devices.match(queries: [Self.firstId.uuidString.uppercased()])

        #expect(lower.matched == [Self.devices[0]])
        #expect(upper.matched == [Self.devices[0]])
        #expect(lower.notFound.isEmpty == true)
    }

    @Test("Matches a device by a case-insensitive name fragment")
    func matchesByNameFragment() -> Void {
        let result = Self.devices.match(queries: ["radiation"])

        #expect(result.matched == [Self.devices[1]])
        #expect(result.notFound.isEmpty == true)
    }

    @Test("Reports queries that match nothing")
    func reportsUnmatchedQueries() -> Void {
        let result = Self.devices.match(queries: ["Aranet2", "nope"])

        #expect(result.matched.isEmpty == true)
        #expect(result.notFound == ["Aranet2", "nope"])
    }

    @Test("Collapses duplicate matches while keeping query order")
    func collapsesDuplicateMatches() -> Void {
        let result = Self.devices.match(queries: ["7E8F9", "1A2B3", "aranet radiation"])

        #expect(result.matched == [Self.devices[1], Self.devices[0]])
        #expect(result.notFound.isEmpty == true)
    }

    @Test("Empty queries produce empty results")
    func emptyQueries() -> Void {
        let result = Self.devices.match(queries: [])

        #expect(result.matched.isEmpty == true)
        #expect(result.notFound.isEmpty == true)
    }

    @Test("A fragment shared by several devices selects the first one")
    func sharedFragmentSelectsFirstDevice() -> Void {
        let result = Self.devices.match(queries: ["aranet"])

        #expect(result.matched == [Self.devices[0]])
    }
}
