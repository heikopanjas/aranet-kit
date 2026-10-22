import AranetKit
import Foundation

/// A fake `read` that answers from a script of results, recording how often it was called.
@MainActor
final class ReadingScript {
    private var results: [Result<AranetReading, any Error>]
    private(set) var readCount = 0
    private(set) var devices: [AranetDevice] = []

    init(_ results: [Result<AranetReading, any Error>]) {
        self.results = results
    }

    func read(_ device: AranetDevice) async throws -> AranetReading {
        self.readCount += 1
        self.devices.append(device)

        guard self.results.isEmpty == false else {
            throw AranetError.readFailed
        }
        return try self.results.removeFirst().get()
    }
}
