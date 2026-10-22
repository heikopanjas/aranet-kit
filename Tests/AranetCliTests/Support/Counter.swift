/// A main-actor counter for callbacks whose invocations a test wants to count.
@MainActor
final class Counter {
    var count = 0
}
