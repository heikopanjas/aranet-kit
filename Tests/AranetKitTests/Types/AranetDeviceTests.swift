import AranetKit
import Foundation
import Testing

@Suite(.tags(.types))
struct AranetDeviceTests {
    @Test("Stores the identifier and name")
    func storesIdentifierAndName() -> Void {
        let id = UUID()
        let device = AranetDevice(id: id, name: "Aranet4 1A2B3")

        #expect(device.id == id)
        #expect(device.name == "Aranet4 1A2B3")
    }

    @Test("Equality covers the identifier and the name")
    func equalityCoversAllFields() -> Void {
        let id = UUID()
        let device = AranetDevice(id: id, name: "Aranet4 1A2B3")

        #expect(device == AranetDevice(id: id, name: "Aranet4 1A2B3"))
        #expect(device != AranetDevice(id: id, name: "Aranet4 renamed"))
        #expect(device != AranetDevice(id: UUID(), name: "Aranet4 1A2B3"))
    }

    @Test("Hashing is consistent with equality")
    func hashingIsConsistent() -> Void {
        let id = UUID()
        let devices: Set<AranetDevice> = [
            AranetDevice(id: id, name: "Aranet4 1A2B3"),
            AranetDevice(id: id, name: "Aranet4 1A2B3"),
            AranetDevice(id: id, name: "Aranet4 renamed")
        ]

        #expect(devices.count == 2)
    }
}
