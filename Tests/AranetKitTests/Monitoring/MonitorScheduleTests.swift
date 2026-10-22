import Foundation
import Testing

@testable import AranetKit

@Suite(.tags(.monitoring))
struct MonitorScheduleTests {
    @Test("Waits until the next device update plus the read margin")
    func waitsUntilNextUpdate() -> Void {
        #expect(MonitorSchedule.nextDelay(interval: 300, ago: 42) == 261)
        #expect(MonitorSchedule.nextDelay(interval: 60, ago: 0) == 63)
    }

    @Test("A missing age falls back to the full interval plus the margin")
    func missingAgeUsesFullInterval() -> Void {
        #expect(MonitorSchedule.nextDelay(interval: 300, ago: nil) == 303)
    }

    @Test("An overdue device is re-read after the minimum delay, not continuously", arguments: [UInt16(300), 301, 310, 65_535])
    func overdueDeviceUsesMinimumDelay(ago: UInt16) -> Void {
        #expect(MonitorSchedule.nextDelay(interval: 300, ago: ago) == MonitorSchedule.minimumDelay)
    }

    @Test("Delays just above the minimum are not clamped")
    func delaysAboveMinimumAreKept() -> Void {
        let delay = MonitorSchedule.nextDelay(interval: 300, ago: 297)

        #expect(delay == MonitorSchedule.readMargin + 3)
        #expect(delay > MonitorSchedule.minimumDelay)
    }

    @Test("Tiny intervals without an age never drop below the minimum")
    func tinyIntervalsRespectMinimum() -> Void {
        #expect(MonitorSchedule.nextDelay(interval: 1, ago: nil) == MonitorSchedule.minimumDelay)
    }
}
