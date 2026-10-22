import Testing

/// Yields to other main-actor work until `condition` holds, recording an issue instead of hanging if it never does.
@MainActor
func settle(_ description: String, until condition: @MainActor () -> Bool) async -> Void {
    for _ in 0 ..< 10_000 {
        if condition() == true {
            return
        }
        await Task.yield()
    }
    Issue.record("Timed out waiting for \(description)")
}
