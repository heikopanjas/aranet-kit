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
        .pairingRequired,
        .operationInProgress
    ]

    @Test("Every error has a description", arguments: AranetErrorTests.allCases)
    func everyErrorHasDescription(error: AranetError) -> Void {
        #expect(error.description.isEmpty == false)
    }

    @Test("The localized description is the description", arguments: AranetErrorTests.allCases)
    func localizedDescriptionMatches(error: AranetError) -> Void {
        #expect(error.errorDescription == error.description)
        #expect(error.localizedDescription == error.description)
        #expect((error as any Error).localizedDescription == error.description)
    }

    @Test("Descriptions are distinct")
    func descriptionsAreDistinct() -> Void {
        let descriptions = Set(Self.allCases.map(\.description))

        #expect(descriptions.count == Self.allCases.count)
    }

    @Test("Pairing guidance mentions the PIN shown on the device without naming a command")
    func pairingGuidanceMentionsPin() -> Void {
        let description = AranetError.pairingRequired.description

        #expect(description.contains("PIN") == true)
        #expect(description.contains("command") == false)
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
