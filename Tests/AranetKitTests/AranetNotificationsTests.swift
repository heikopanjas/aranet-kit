import Foundation
import Testing

@testable import AranetKit

@Suite(.tags(.notifications))
struct AranetNotificationsTests {
    @Test("Notification name and keys are namespaced")
    func notificationNameAndKeysAreNamespaced() -> Void {
        #expect(Notification.Name.aranetReadingDidUpdate.rawValue == "AranetKit.readingDidUpdate")
        #expect(AranetNotificationKey.device == "AranetKit.device")
        #expect(AranetNotificationKey.reading == "AranetKit.reading")
        #expect(AranetNotificationKey.receivedAt == "AranetKit.receivedAt")
    }

    @Test("Posting a reading delivers the device, the reading, and the receive time")
    func postingDeliversUserInfo() async -> Void {
        let device = AranetDevice(id: UUID(), name: "Aranet4 TEST")
        let reading = ReadingFixtures.aranet4(co2: 1_234)
        let before = Date()

        await confirmation("reading notification observed") { observed in
            let token = NotificationCenter.default.addObserver(forName: .aranetReadingDidUpdate, object: nil, queue: nil) { notification in
                guard let postedDevice = notification.userInfo?[AranetNotificationKey.device] as? AranetDevice,
                    postedDevice.id == device.id
                else { return }

                let postedReading = notification.userInfo?[AranetNotificationKey.reading] as? AranetReading
                let receivedAt = notification.userInfo?[AranetNotificationKey.receivedAt] as? Date

                #expect(postedDevice == device)
                #expect(postedReading?.co2 == 1_234)
                #expect((receivedAt ?? Date.distantPast) >= before)
                #expect((receivedAt ?? Date.distantFuture) <= Date())
                observed()
            }
            defer { NotificationCenter.default.removeObserver(token) }

            AranetNotifications.postReadingDidUpdate(device: device, reading: reading)
        }
    }

    @Test("Each posting delivers exactly one notification")
    func eachPostingDeliversOnce() async -> Void {
        let device = AranetDevice(id: UUID(), name: "Aranet2 TEST")
        let reading = ReadingFixtures.aranet2()

        await confirmation("three notifications observed", expectedCount: 3) { observed in
            let token = NotificationCenter.default.addObserver(forName: .aranetReadingDidUpdate, object: nil, queue: nil) { notification in
                guard let postedDevice = notification.userInfo?[AranetNotificationKey.device] as? AranetDevice,
                    postedDevice.id == device.id
                else { return }
                observed()
            }
            defer { NotificationCenter.default.removeObserver(token) }

            for _ in 0 ..< 3 {
                AranetNotifications.postReadingDidUpdate(device: device, reading: reading)
            }
        }
    }
}
