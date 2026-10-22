import Testing

/// Yields to other main-actor work until `condition` holds, recording an issue instead of hanging if it never does.
///
/// Bounded by both a yield count and wall-clock time, so a slow executor still produces a diagnostic.
@MainActor
func settle(_ description: String, until condition: @MainActor () -> Bool) async -> Void {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))

    for _ in 0 ..< 10_000 where clock.now < deadline {
        if condition() == true {
            return
        }
        await Task.yield()
    }
    if condition() == true {
        return
    }
    Issue.record("Timed out waiting for \(description)")
}
