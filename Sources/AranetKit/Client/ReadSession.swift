//
// ReadSession.swift
// AranetKit
//
// Swift reimplementation of the Python aranet4 library
// Based on https://github.com/Anrijs/Aranet4-Python
//
// Copyright (c) 2022 Anrijs Jargans (original Python implementation)
// Copyright (c) 2025 Heiko Panjas (Swift reimplementation)
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth
import Foundation

/// The state machine of one read against one peripheral.
///
/// It turns ``BluetoothEvent`` values into ``ReadCommand`` values and keeps every piece of
/// per-read state, so concurrent reads from several peripherals cannot interfere. It holds no
/// CoreBluetooth objects and is fully testable.
struct ReadSession {
    let peripheralId: UUID
    let peripheralName: String?

    private(set) var deviceName = ""
    private(set) var deviceVersion = ""
    private(set) var readingData: Data?
    private(set) var readingCharacteristic: CBUUID?
    private(set) var pendingReads: Set<CBUUID> = []
    private(set) var servicesDiscovered = 0
    private(set) var expectedServices = 0
    private(set) var encryptionErrors = 0
    private(set) var isFinished = false
    private var availableReadingCharacteristics: [CBUUID: CBUUID] = [:]

    init(peripheralId: UUID, peripheralName: String?) {
        self.peripheralId = peripheralId
        self.peripheralName = peripheralName
    }

    /// True while reading characteristics have failed with encryption errors and no data has arrived.
    var isPairingSuspected: Bool {
        return self.encryptionErrors > 0 && self.readingData == nil
    }

    /// The name to store on the reading: the GAP device name, else the advertised name.
    var resolvedName: String {
        if self.deviceName.isEmpty == true {
            return self.peripheralName ?? "Unknown"
        }
        return self.deviceName
    }

    /// Applies an event and returns the commands to execute. Events for other peripherals and events after completion are ignored.
    mutating func handle(_ event: BluetoothEvent) -> [ReadCommand] {
        guard self.isFinished == false else { return [] }

        switch event {
            case .connected(let id):
                guard id == self.peripheralId else { return [] }
                return [.discoverServices]
            case .connectFailed(let id, let error):
                guard id == self.peripheralId else { return [] }
                return self.finish(with: error ?? AranetError.connectionFailed)
            case .disconnected(let id, let error):
                guard id == self.peripheralId else { return [] }
                return self.finish(with: error ?? AranetError.connectionFailed)
            case .servicesDiscovered(let id, let services, let error):
                guard id == self.peripheralId else { return [] }
                return self.handleServices(services, error: error)
            case .characteristicsDiscovered(let id, let service, let characteristics, let error):
                guard id == self.peripheralId else { return [] }
                return self.handleCharacteristics(characteristics, in: service, error: error)
            case .valueUpdated(let id, let characteristic, let data, let error):
                guard id == self.peripheralId else { return [] }
                return self.handleValue(data, for: characteristic, error: error)
            case .stateChanged, .discovered:
                return []
        }
    }

    // MARK: - Private

    private mutating func finish(with error: any Error) -> [ReadCommand] {
        self.isFinished = true
        return [.fail(error)]
    }

    private mutating func handleServices(_ services: [CBUUID], error: (any Error)?) -> [ReadCommand] {
        if let error {
            return self.finish(with: error)
        }
        guard services.isEmpty == false else {
            return self.finish(with: AranetError.readFailed)
        }

        self.expectedServices = services.count
        return services.map { ReadCommand.discoverCharacteristics(service: $0) }
    }

    private mutating func handleCharacteristics(_ characteristics: [CBUUID], in service: CBUUID, error: (any Error)?) -> [ReadCommand] {
        self.servicesDiscovered += 1
        var commands: [ReadCommand] = []

        if error == nil {
            for characteristic in characteristics {
                if characteristic == AranetUUID.characteristicDeviceName || characteristic == AranetUUID.characteristicSoftwareRevision {
                    self.pendingReads.insert(characteristic)
                    commands.append(.read(service: service, characteristic: characteristic))
                }
                else if AranetUUID.readingCharacteristics.contains(characteristic) == true {
                    self.availableReadingCharacteristics[characteristic] = service
                }
            }
        }

        guard self.servicesDiscovered == self.expectedServices else {
            return commands
        }

        let preferred = AranetUUID.readingCharacteristicPriority.first { self.availableReadingCharacteristics[$0] != nil }
        guard let readingCharacteristic = preferred, let readingService = self.availableReadingCharacteristics[readingCharacteristic] else {
            return self.finish(with: AranetError.readFailed)
        }

        self.readingCharacteristic = readingCharacteristic
        self.pendingReads.insert(readingCharacteristic)
        commands.append(.read(service: readingService, characteristic: readingCharacteristic))
        return commands
    }

    private mutating func handleValue(_ data: Data?, for characteristic: CBUUID, error: (any Error)?) -> [ReadCommand] {
        self.pendingReads.remove(characteristic)
        let isReadingCharacteristic = AranetUUID.readingCharacteristics.contains(characteristic)

        if let error {
            if Self.isEncryptionError(error) == true {
                if isReadingCharacteristic == true {
                    self.encryptionErrors += 1
                }
                return []
            }
            if isReadingCharacteristic == true {
                return self.finish(with: error)
            }
            return self.completeIfReady()
        }

        guard let data else {
            if isReadingCharacteristic == true {
                self.encryptionErrors += 1
            }
            return self.completeIfReady()
        }

        if characteristic == AranetUUID.characteristicDeviceName {
            self.deviceName = String(data: data, encoding: .utf8) ?? ""
        }
        else if characteristic == AranetUUID.characteristicSoftwareRevision {
            self.deviceVersion = String(data: data, encoding: .utf8) ?? ""
        }
        else if isReadingCharacteristic == true {
            self.readingData = data
        }

        return self.completeIfReady()
    }

    private mutating func completeIfReady() -> [ReadCommand] {
        guard self.pendingReads.isEmpty == true, let data = self.readingData else {
            return []
        }

        self.isFinished = true
        return [.complete(data: data, name: self.resolvedName, version: self.deviceVersion)]
    }

    /// Reads of characteristics that require pairing fail with an ATT insufficient-encryption error.
    private static func isEncryptionError(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == CBATTErrorDomain && nsError.code == CBATTError.insufficientEncryption.rawValue
    }
}
