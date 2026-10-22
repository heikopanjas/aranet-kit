import CoreBluetooth
import Foundation
import Testing

@testable import AranetKit

/// `ReadCommand` carries `any Error`, so tests compare this Equatable projection instead.
enum CommandShape: Equatable {
    case discoverServices
    case discoverCharacteristics(CBUUID)
    case read(service: CBUUID, characteristic: CBUUID)
    case complete(Data, name: String, version: String)
    case fail(AranetError)
    case failOther(String)

    init(_ command: ReadCommand) {
        switch command {
            case .discoverServices:
                self = .discoverServices
            case .discoverCharacteristics(let service):
                self = .discoverCharacteristics(service)
            case .read(let service, let characteristic):
                self = .read(service: service, characteristic: characteristic)
            case .complete(let data, let name, let version):
                self = .complete(data, name: name, version: version)
            case .fail(let error):
                if let aranetError = error as? AranetError {
                    self = .fail(aranetError)
                }
                else {
                    self = .failOther((error as NSError).domain)
                }
        }
    }
}

@Suite(.tags(.bluetooth))
struct ReadSessionTests {
    private static let id = UUID()
    private static let otherId = UUID()
    private static let gap = AranetUUID.serviceGAP
    private static let dis = AranetUUID.serviceDIS
    private static let saf = AranetUUID.serviceSAFTehnika
    private static let deviceName = AranetUUID.characteristicDeviceName
    private static let revision = AranetUUID.characteristicSoftwareRevision
    private static let detailed = AranetUUID.characteristicCurrentReadingsDetailed
    private static let basic = AranetUUID.characteristicCurrentReadings
    private static let ar2 = AranetUUID.characteristicCurrentReadingsAR2
    private static let ar2Detailed = AranetUUID.characteristicCurrentReadingsAR2Detailed
    private static let encryptionError = NSError(domain: CBATTErrorDomain, code: CBATTError.insufficientEncryption.rawValue)
    private static let otherError = NSError(domain: "TestDomain", code: 42)

    private func session() -> ReadSession {
        return ReadSession(peripheralId: Self.id, peripheralName: "Aranet4 ADV")
    }

    private func shapes(_ commands: [ReadCommand]) -> [CommandShape] {
        return commands.map(CommandShape.init)
    }

    /// Drives a session through connect and discovery of GAP, DIS, and SAF with the given reading characteristics.
    private func discovered(_ session: inout ReadSession, readingCharacteristics: [CBUUID]) -> [CommandShape] {
        _ = session.handle(.connected(Self.id))
        _ = session.handle(.servicesDiscovered(Self.id, [Self.gap, Self.dis, Self.saf], nil))
        _ = session.handle(.characteristicsDiscovered(Self.id, service: Self.gap, [Self.deviceName], nil))
        _ = session.handle(.characteristicsDiscovered(Self.id, service: Self.dis, [Self.revision], nil))
        return self.shapes(session.handle(.characteristicsDiscovered(Self.id, service: Self.saf, readingCharacteristics, nil)))
    }

    // MARK: - Connection

    @Test("Connecting discovers services")
    func connectedDiscoversServices() -> Void {
        var session = self.session()

        #expect(self.shapes(session.handle(.connected(Self.id))) == [.discoverServices])
        #expect(session.isFinished == false)
    }

    @Test("A failed connection fails the read with the underlying error or connectionFailed")
    func connectFailed() -> Void {
        var withError = self.session()
        var withoutError = self.session()

        #expect(self.shapes(withError.handle(.connectFailed(Self.id, Self.otherError))) == [.failOther("TestDomain")])
        #expect(self.shapes(withoutError.handle(.connectFailed(Self.id, nil))) == [.fail(.connectionFailed)])
        #expect(withError.isFinished == true)
    }

    @Test("A disconnect during the read fails it immediately")
    func disconnectFailsRead() -> Void {
        var session = self.session()
        _ = session.handle(.connected(Self.id))

        #expect(self.shapes(session.handle(.disconnected(Self.id, nil))) == [.fail(.connectionFailed)])
        #expect(session.isFinished == true)
    }

    // MARK: - Discovery

    @Test("Each discovered service gets its characteristics discovered")
    func servicesDiscovered() -> Void {
        var session = self.session()
        let commands = session.handle(.servicesDiscovered(Self.id, [Self.gap, Self.saf], nil))

        #expect(self.shapes(commands) == [.discoverCharacteristics(Self.gap), .discoverCharacteristics(Self.saf)])
        #expect(session.expectedServices == 2)
    }

    @Test("A service discovery error fails the read")
    func serviceDiscoveryError() -> Void {
        var session = self.session()

        #expect(self.shapes(session.handle(.servicesDiscovered(Self.id, [], Self.otherError))) == [.failOther("TestDomain")])
    }

    @Test("A peripheral without services cannot be read")
    func noServices() -> Void {
        var session = self.session()

        #expect(self.shapes(session.handle(.servicesDiscovered(Self.id, [], nil))) == [.fail(.readFailed)])
    }

    @Test("Name and revision characteristics are read as they are discovered")
    func nameAndRevisionAreRead() -> Void {
        var session = self.session()
        _ = session.handle(.servicesDiscovered(Self.id, [Self.gap, Self.dis, Self.saf], nil))

        let gapCharacteristics = [Self.deviceName, AranetUUID.characteristicSerialNumber]
        let gapCommands = session.handle(.characteristicsDiscovered(Self.id, service: Self.gap, gapCharacteristics, nil))
        let disCommands = session.handle(.characteristicsDiscovered(Self.id, service: Self.dis, [Self.revision], nil))

        #expect(self.shapes(gapCommands) == [.read(service: Self.gap, characteristic: Self.deviceName)])
        #expect(self.shapes(disCommands) == [.read(service: Self.dis, characteristic: Self.revision)])
        #expect(session.pendingReads == [Self.deviceName, Self.revision])
    }

    @Test("The preferred reading characteristic is read once every service is discovered")
    func preferredReadingCharacteristic() -> Void {
        var session = self.session()
        let commands = self.discovered(&session, readingCharacteristics: [Self.basic, Self.detailed])

        #expect(commands == [.read(service: Self.saf, characteristic: Self.detailed)])
        #expect(session.readingCharacteristic == Self.detailed)
        #expect(session.pendingReads.contains(Self.detailed) == true)
    }

    @Test(
        "Reading characteristics are chosen by priority",
        arguments: zip(
            [[AranetUUID.characteristicCurrentReadingsAR2Detailed, AranetUUID.characteristicCurrentReadingsAR2],
             [AranetUUID.characteristicCurrentReadings, AranetUUID.characteristicCurrentReadingsAR2],
             [AranetUUID.characteristicCurrentReadings]],
            [
                AranetUUID.characteristicCurrentReadingsAR2Detailed,
                AranetUUID.characteristicCurrentReadingsAR2,
                AranetUUID.characteristicCurrentReadings
            ]
        )
    )
    func readingCharacteristicPriority(available: [CBUUID], expected: CBUUID) -> Void {
        var session = self.session()
        let commands = self.discovered(&session, readingCharacteristics: available)

        #expect(commands == [.read(service: Self.saf, characteristic: expected)])
    }

    @Test("Without any reading characteristic the read fails at once, even with name reads pending")
    func noReadingCharacteristicFailsImmediately() -> Void {
        var session = self.session()
        let commands = self.discovered(&session, readingCharacteristics: [])

        #expect(commands == [.fail(.readFailed)])
        #expect(session.isFinished == true)
    }

    @Test("A characteristic discovery error on the last service still completes discovery")
    func characteristicDiscoveryErrorOnLastService() -> Void {
        var session = self.session()
        _ = session.handle(.servicesDiscovered(Self.id, [Self.saf, Self.dis], nil))
        _ = session.handle(.characteristicsDiscovered(Self.id, service: Self.saf, [Self.detailed], nil))

        let commands = session.handle(.characteristicsDiscovered(Self.id, service: Self.dis, [], Self.otherError))

        #expect(self.shapes(commands) == [.read(service: Self.saf, characteristic: Self.detailed)])
    }

    @Test("Discovery waits until every service reported its characteristics")
    func discoveryWaitsForAllServices() -> Void {
        var session = self.session()
        _ = session.handle(.servicesDiscovered(Self.id, [Self.saf, Self.dis], nil))

        let commands = session.handle(.characteristicsDiscovered(Self.id, service: Self.saf, [Self.detailed], nil))

        #expect(commands.isEmpty == true)
        #expect(session.readingCharacteristic == nil)
    }

    // MARK: - Values

    @Test("The read completes once the reading data and all pending reads arrived")
    func completesWithNameAndVersion() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.detailed])

        #expect(session.handle(.valueUpdated(Self.id, characteristic: Self.deviceName, Data("Aranet4 GAP".utf8), nil)).isEmpty == true)
        #expect(session.handle(.valueUpdated(Self.id, characteristic: Self.revision, Data("1.4.14".utf8), nil)).isEmpty == true)

        let commands = session.handle(.valueUpdated(Self.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))

        #expect(self.shapes(commands) == [.complete(PayloadFixtures.aranet4Detailed, name: "Aranet4 GAP", version: "1.4.14")])
        #expect(session.isFinished == true)
    }

    @Test("Reading data that arrives before the name waits for the name")
    func readingDataWaitsForPendingReads() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.detailed])

        #expect(session.handle(.valueUpdated(Self.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil)).isEmpty == true)
        #expect(session.handle(.valueUpdated(Self.id, characteristic: Self.revision, Data("1.4.14".utf8), nil)).isEmpty == true)

        let commands = session.handle(.valueUpdated(Self.id, characteristic: Self.deviceName, Data("Aranet4 GAP".utf8), nil))

        #expect(self.shapes(commands) == [.complete(PayloadFixtures.aranet4Detailed, name: "Aranet4 GAP", version: "1.4.14")])
    }

    @Test("Without a GAP name the advertised name is used, and without that a placeholder")
    func nameFallbacks() -> Void {
        var advertised = self.session()
        _ = advertised.handle(.servicesDiscovered(Self.id, [Self.saf], nil))
        _ = advertised.handle(.characteristicsDiscovered(Self.id, service: Self.saf, [Self.detailed], nil))
        let advertisedCommands = advertised.handle(.valueUpdated(Self.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))

        var anonymous = ReadSession(peripheralId: Self.id, peripheralName: nil)
        _ = anonymous.handle(.servicesDiscovered(Self.id, [Self.saf], nil))
        _ = anonymous.handle(.characteristicsDiscovered(Self.id, service: Self.saf, [Self.detailed], nil))
        let anonymousCommands = anonymous.handle(.valueUpdated(Self.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))

        #expect(self.shapes(advertisedCommands) == [.complete(PayloadFixtures.aranet4Detailed, name: "Aranet4 ADV", version: "")])
        #expect(self.shapes(anonymousCommands) == [.complete(PayloadFixtures.aranet4Detailed, name: "Unknown", version: "")])
    }

    @Test("Undecodable name and revision bytes become empty strings")
    func undecodableStrings() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.detailed])
        let invalidUTF8 = Data([0xFF, 0xFE])

        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.deviceName, invalidUTF8, nil))
        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.revision, invalidUTF8, nil))
        let commands = session.handle(.valueUpdated(Self.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))

        #expect(self.shapes(commands) == [.complete(PayloadFixtures.aranet4Detailed, name: "Aranet4 ADV", version: "")])
    }

    @Test("Encryption errors on reading characteristics are counted and suggest pairing")
    func encryptionErrorsSuggestPairing() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.basic])

        let commands = session.handle(.valueUpdated(Self.id, characteristic: Self.basic, nil, Self.encryptionError))

        #expect(commands.isEmpty == true)
        #expect(session.encryptionErrors == 1)
        #expect(session.isPairingSuspected == true)
        #expect(session.isFinished == false)
    }

    @Test("A reading characteristic that returns no data also counts as an encryption error")
    func nilDataCountsAsEncryptionError() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.basic])

        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.basic, nil, nil))

        #expect(session.encryptionErrors == 1)
        #expect(session.isPairingSuspected == true)
    }

    @Test("Encryption errors on other characteristics are ignored")
    func encryptionErrorsOnOtherCharacteristicsAreIgnored() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.detailed])

        let commands = session.handle(.valueUpdated(Self.id, characteristic: Self.deviceName, nil, Self.encryptionError))

        #expect(commands.isEmpty == true)
        #expect(session.encryptionErrors == 0)
        #expect(session.pendingReads.contains(Self.deviceName) == false)
    }

    @Test("Pairing is no longer suspected once reading data arrives")
    func pairingNotSuspectedAfterData() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.basic, Self.detailed])

        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.basic, nil, Self.encryptionError))
        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))

        #expect(session.isPairingSuspected == false)
    }

    @Test("A non-encryption error on the reading characteristic fails the read")
    func otherErrorOnReadingCharacteristicFails() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.detailed])

        let commands = session.handle(.valueUpdated(Self.id, characteristic: Self.detailed, nil, Self.otherError))

        #expect(self.shapes(commands) == [.failOther("TestDomain")])
    }

    @Test("A non-encryption error on a name read drops it and the read can still complete")
    func otherErrorOnNameRead() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.detailed])

        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))
        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.revision, Data("1.0".utf8), nil))
        let commands = session.handle(.valueUpdated(Self.id, characteristic: Self.deviceName, nil, Self.otherError))

        #expect(self.shapes(commands) == [.complete(PayloadFixtures.aranet4Detailed, name: "Aranet4 ADV", version: "1.0")])
    }

    @Test("A name read that returns no data is dropped and the read can still complete")
    func nilNameIsDropped() -> Void {
        var session = self.session()
        _ = self.discovered(&session, readingCharacteristics: [Self.detailed])

        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil))
        _ = session.handle(.valueUpdated(Self.id, characteristic: Self.revision, Data("1.0".utf8), nil))
        let commands = session.handle(.valueUpdated(Self.id, characteristic: Self.deviceName, nil, nil))

        #expect(self.shapes(commands) == [.complete(PayloadFixtures.aranet4Detailed, name: "Aranet4 ADV", version: "1.0")])
    }

    // MARK: - Isolation

    @Test("Events for other peripherals are ignored")
    func otherPeripheralsAreIgnored() -> Void {
        var session = self.session()

        #expect(session.handle(.connected(Self.otherId)).isEmpty == true)
        #expect(session.handle(.connectFailed(Self.otherId, nil)).isEmpty == true)
        #expect(session.handle(.disconnected(Self.otherId, nil)).isEmpty == true)
        #expect(session.handle(.servicesDiscovered(Self.otherId, [Self.saf], nil)).isEmpty == true)
        #expect(session.handle(.characteristicsDiscovered(Self.otherId, service: Self.saf, [Self.detailed], nil)).isEmpty == true)
        #expect(session.handle(.valueUpdated(Self.otherId, characteristic: Self.detailed, PayloadFixtures.aranet4Detailed, nil)).isEmpty == true)
        #expect(session.isFinished == false)
    }

    @Test("Central-level events are ignored")
    func centralEventsAreIgnored() -> Void {
        var session = self.session()

        #expect(session.handle(.stateChanged(.poweredOff)).isEmpty == true)
        #expect(session.handle(.discovered(PeripheralInfo(id: Self.id, name: nil), rssi: -40)).isEmpty == true)
    }

    @Test("Events after completion are ignored")
    func eventsAfterCompletionAreIgnored() -> Void {
        var session = self.session()
        _ = session.handle(.connectFailed(Self.id, nil))

        #expect(session.handle(.connected(Self.id)).isEmpty == true)
        #expect(session.handle(.disconnected(Self.id, nil)).isEmpty == true)
    }

    @Test("Every event reports its peripheral")
    func eventPeripheralIds() -> Void {
        #expect(BluetoothEvent.stateChanged(.poweredOn).peripheralId == nil)
        #expect(BluetoothEvent.discovered(PeripheralInfo(id: Self.id, name: nil), rssi: 0).peripheralId == nil)
        #expect(BluetoothEvent.connected(Self.id).peripheralId == Self.id)
        #expect(BluetoothEvent.connectFailed(Self.id, nil).peripheralId == Self.id)
        #expect(BluetoothEvent.disconnected(Self.id, nil).peripheralId == Self.id)
        #expect(BluetoothEvent.servicesDiscovered(Self.id, [], nil).peripheralId == Self.id)
        #expect(BluetoothEvent.characteristicsDiscovered(Self.id, service: Self.saf, [], nil).peripheralId == Self.id)
        #expect(BluetoothEvent.valueUpdated(Self.id, characteristic: Self.detailed, nil, nil).peripheralId == Self.id)
    }
}
