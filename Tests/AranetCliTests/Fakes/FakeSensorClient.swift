import AranetKit
import Foundation

/// A `SensorClient` that answers from scripted results and records every call.
@MainActor
final class FakeSensorClient: SensorClient {
    var verbose = false
    var scanResult: Result<[AranetDevice], any Error> = .success([])
    var readResults: [UUID: Result<AranetReading, any Error>] = [:]
    var monitorStreams: [UUID: AsyncStream<Result<AranetReading, any Error>>] = [:]

    private(set) var scanTimeouts: [TimeInterval] = []
    private(set) var readDevices: [AranetDevice] = []
    private(set) var monitoredDevices: [AranetDevice] = []

    func scan(timeout: TimeInterval) async throws -> [AranetDevice] {
        self.scanTimeouts.append(timeout)
        return try self.scanResult.get()
    }

    func readCurrentReadings(from device: AranetDevice) async throws -> AranetReading {
        self.readDevices.append(device)
        guard let result = self.readResults[device.id] else {
            throw AranetError.deviceNotFound
        }
        return try result.get()
    }

    func monitor(from device: AranetDevice) -> AsyncStream<Result<AranetReading, any Error>> {
        self.monitoredDevices.append(device)
        if let stream = self.monitorStreams[device.id] {
            return stream
        }

        let (stream, continuation) = AsyncStream.makeStream(of: Result<AranetReading, any Error>.self)
        continuation.finish()
        return stream
    }

    /// Scripts a monitor stream for `device` that yields `readings`, then the failure when given, then finishes.
    func scriptMonitor(for device: AranetDevice, readings: [AranetReading], thenFailWith error: (any Error)? = nil) -> Void {
        let (stream, continuation) = AsyncStream.makeStream(of: Result<AranetReading, any Error>.self)
        for reading in readings {
            continuation.yield(.success(reading))
        }
        if let error {
            continuation.yield(.failure(error))
        }
        continuation.finish()
        self.monitorStreams[device.id] = stream
    }

    /// Scripts a monitor stream for `device` that the test feeds by hand.
    func openMonitor(for device: AranetDevice) -> AsyncStream<Result<AranetReading, any Error>>.Continuation {
        let (stream, continuation) = AsyncStream.makeStream(of: Result<AranetReading, any Error>.self)
        self.monitorStreams[device.id] = stream
        return continuation
    }
}
