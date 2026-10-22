import Testing

@testable import AranetKit

@MainActor
@Suite(.tags(.bluetooth))
struct AranetLogTests {
    @Test("The standard sink accepts messages and writes them to the unified log")
    func standardSinkAcceptsMessages() -> Void {
        AranetLog.standard("AranetLogTests: standard sink smoke test")
        AranetLog.standard("")
    }
}
