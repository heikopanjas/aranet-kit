import AranetKit
import Foundation
import Testing

@Suite(.tags(.types))
struct AranetErrorTests {
    private static let allCases: [AranetError] = [
        .bluetoothUnavailable,
        .bluetoothUnauthorized,
        .bluetoothUnsupported,
        .deviceNotFound,
        .connectionFailed,
        .readFailed,
        .invalidData,
        .timeout,
        .pairingRequired
    ]

    @Test("Every error has a description", arguments: AranetErrorTests.allCases)
    func everyErrorHasDescription(error: AranetError) -> Void {
        #expect(error.description.isEmpty == false)
    }

    @Test("Descriptions are distinct")
    func descriptionsAreDistinct() -> Void {
        let descriptions = Set(Self.allCases.map(\.description))

        #expect(descriptions.count == Self.allCases.count)
    }

    @Test("Pairing guidance mentions the PIN shown on the device")
    func pairingGuidanceMentionsPin() -> Void {
        #expect(AranetError.pairingRequired.description.contains("PIN") == true)
    }

    @Test("Unauthorized guidance points at System Settings")
    func unauthorizedGuidancePointsAtSystemSettings() -> Void {
        #expect(AranetError.bluetoothUnauthorized.description.contains("System Settings") == true)
    }

    @Test("Errors can be thrown and matched")
    func errorsCanBeThrownAndMatched() -> Void {
        #expect(throws: AranetError.timeout) {
            throw AranetError.timeout
        }
    }
}
