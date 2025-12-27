//
//  SwiftBoardEngine.swift
//  MetaWear
//
//  Created by Laura Kassovic on 12/26/25.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Module constants (mirror metawearboard.cpp)
private enum ModuleID: UInt8 {
    case switchModule          = 0x01
    case led                   = 0x02
    case accelerometer         = 0x03
    case temperature           = 0x04
    case gpio                  = 0x05
    case neoPixel              = 0x06
    case iBeacon               = 0x07
    case haptic                = 0x08
    case dataProcessor         = 0x09
    case eventModule           = 0x0a
    case logging               = 0x0b
    case timer                 = 0x0c
    case i2c                   = 0x0d
    case macro                 = 0x0e
    case conductance           = 0x0f
    case settings              = 0x11
    case barometer             = 0x12
    case gyro                  = 0x13
    case ambientLight          = 0x14
    case magnetometer          = 0x15
    case humidity              = 0x16
    case colorDetector         = 0x17
    case proximity             = 0x18
    case sensorFusion          = 0x19
    case debug                 = 0xfe
}

private let READ_INFO_REGISTER: UInt8 = 0x00

// The ordered discovery commands (MODULE_DISCOVERY_CMDS)
private let moduleDiscoveryOrder: [ModuleID] = [
    .switchModule,
    .led,
    .accelerometer,
    .temperature,
    .gpio,
    .neoPixel,
    .iBeacon,
    .haptic,
    .dataProcessor,
    .eventModule,
    .logging,
    .timer,
    .i2c,
    .macro,
    .conductance,
    .settings,
    .barometer,
    .gyro,
    .ambientLight,
    .magnetometer,
    .humidity,
    .colorDetector,
    .proximity,
    .sensorFusion,
    .debug
]

// MARK: - DIS UUIDs (Device Information Service)
private struct DIS {
    static let service = CBUUID(string: "180A")
    static let firmware = CBUUID(string: "2A26")
    static let model = CBUUID(string: "2A24")
    static let hardware = CBUUID(string: "2A27")
    static let manufacturer = CBUUID(string: "2A29")
    static let serial = CBUUID(string: "2A25")
}

final class MetaWearWire {
    private let peripheral: CBPeripheral
    private var commandChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?
    private let queue: DispatchQueue

    private let notifySubject = PassthroughSubject<Data, Never>()

    init(peripheral: CBPeripheral, commandChar: CBCharacteristic?, notifyChar: CBCharacteristic?, queue: DispatchQueue) {
        self.peripheral = peripheral
        self.commandChar = commandChar
        self.notifyChar = notifyChar
        self.queue = queue
    }

    func update(commandChar: CBCharacteristic?, notifyChar: CBCharacteristic?) {
        self.commandChar = commandChar
        self.notifyChar = notifyChar
    }

    func write(_ data: Data, expectsResponse: Bool) -> AnyPublisher<Data?, MWError> {
        guard let commandChar = commandChar else {
            return Fail(outputType: Data?.self, failure: MWError.operationFailed("Command characteristic unavailable")).eraseToAnyPublisher()
        }
        return Future<Data?, MWError> { [weak self] promise in
            guard let self = self else { return }
            self.queue.async {
                let type: CBCharacteristicWriteType = expectsResponse ? .withResponse : .withoutResponse
                self.peripheral.writeValue(data, for: commandChar, type: type)
                promise(.success(nil))
            }
        }
        .eraseToAnyPublisher()
    }

    func notifications() -> AnyPublisher<Data, Never> {
        notifySubject.eraseToAnyPublisher()
    }

    // Bridge from MetaWear.didUpdateValueFor
    func _didReceiveNotification(_ data: Data) {
        notifySubject.send(data)
    }

    // Convenience DIS reads
    func readDISString(_ uuid: CBUUID) -> AnyPublisher<String, MWError> {
        return Future<String, MWError> { [weak self] promise in
            guard let self = self else { return }
            self.queue.async {
                guard let service = self.peripheral.services?.first(where: { $0.uuid == DIS.service }),
                      let characteristic = service.characteristics?.first(where: { $0.uuid == uuid }) else {
                    promise(.failure(MWError.operationFailed("DIS characteristic \(uuid.uuidString) unavailable")))
                    return
                }
                // We'll listen for didUpdateValueFor in MetaWear and pick up the value directly here by CB read.
                // For simplicity, do a one-shot KVO-like hook by using a temporary delegate funnel.
                let token = NotificationCenter.default.addObserver(forName: .MWInternalDidUpdateValue, object: self.peripheral, queue: nil) { note in
                    guard let info = note.userInfo as? [String: Any],
                          let ch = info["characteristic"] as? CBCharacteristic,
                          ch.uuid == uuid,
                          let data = ch.value else { return }
                    let str = String(data: data, encoding: .utf8) ?? ""
                    promise(.success(str))
                }
                self.peripheral.readValue(for: characteristic)
                // Timeout safeguard (2s)
                self.queue.asyncAfter(deadline: .now() + 2.0) {
                    NotificationCenter.default.removeObserver(token)
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

public final class SwiftBoardEngine: BoardEngine {
    private var wire: MetaWearWire?
    private var queue: DispatchQueue = .main

    // State during init
    private var isMetaBoot: Bool = false

    public init() {}

    public func initialize(peripheral: CBPeripheral, commandChar: CBCharacteristic?, notifyChar: CBCharacteristic?, queue: DispatchQueue) {
        self.queue = queue
        if let wire = wire {
            wire.update(commandChar: commandChar, notifyChar: notifyChar)
        } else {
            wire = MetaWearWire(peripheral: peripheral, commandChar: commandChar, notifyChar: notifyChar, queue: queue)
        }
    }

    public func notifications() -> AnyPublisher<Data, Never> {
        guard let wire = wire else { return Empty().eraseToAnyPublisher() }
        return wire.notifications()
    }

    public func send(_ data: Data, expectsResponse: Bool) -> AnyPublisher<Data?, MWError> {
        guard let wire = wire else {
            return Fail(outputType: Data?.self, failure: MWError.operationFailed("Board engine not configured")).eraseToAnyPublisher()
        }
        return wire.write(data, expectsResponse: expectsResponse)
    }

    // MARK: - Initialization pipeline (parity with C++)
    public func startInitialization() -> AnyPublisher<BoardState, MWError> {
        guard let wire = wire else {
            return Fail(error: MWError.operationFailed("Board engine not configured")).eraseToAnyPublisher()
        }

        // 1) Read DIS in order: firmware -> model -> hardware -> manufacturer -> serial
        let firmware = wire.readDISString(DIS.firmware).replaceError(with: "").setFailureType(to: MWError.self)
        let model = wire.readDISString(DIS.model).replaceError(with: "").setFailureType(to: MWError.self)
        let hardware = wire.readDISString(DIS.hardware).replaceError(with: "").setFailureType(to: MWError.self)
        let manufacturer = wire.readDISString(DIS.manufacturer).replaceError(with: "").setFailureType(to: MWError.self)
        let serial = wire.readDISString(DIS.serial).replaceError(with: "").setFailureType(to: MWError.self)

        let discovery = discoverModules()

        return firmware
            .combineLatest(model)
            .combineLatest(hardware)
            .combineLatest(manufacturer)
            .combineLatest(serial)
            .flatMap { value -> AnyPublisher<(BoardState, [UInt8: BoardState.ModuleInfo]), MWError> in
                // Unpack nested combineLatest tuple: ((((fw, md), hw), mft), sn)
                let a = value.0          // ((fw, md), hw)
                let sn = value.1         // serial
                let b = a.0              // (fw, md)
                let mft = a.1            // manufacturer
                let c = b.0              // fw
                let hw = b.1             // hardware
                let fw = c.0             // firmware
                let md = c.1             // model
                let preliminary = BoardState(
                    isMetaBoot: self.isMetaBoot,
                    firmwareRevision: fw.isEmpty ? nil : fw,
                    hardwareRevision: hw.isEmpty ? nil : hw,
                    modelNumber: md.isEmpty ? nil : md,
                    manufacturerName: mft.isEmpty ? nil : mft,
                    serialNumber: sn.isEmpty ? nil : sn,
                    moduleInfo: [:]
                )
                return discovery
                    .map { moduleMap in (preliminary, moduleMap) }
                    .eraseToAnyPublisher()
            }
            .map { prelim, modules in
                var state = prelim
                state.moduleInfo = modules
                return state
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Module discovery (mirrors MODULE_DISCOVERY_CMDS + char_changed_handler)
    private func discoverModules() -> AnyPublisher<[UInt8: BoardState.ModuleInfo], MWError> {
        guard let wire = wire else {
            return Fail(error: MWError.operationFailed("Board engine not configured")).eraseToAnyPublisher()
        }

        // We will send commands in order and watch notifications for responses:
        // Response format in C++: header = (module_id, register_id), body contains module info
        // We assume device responds with at least 4 bytes:
        // [module_id, READ_INFO_REGISTER, present/impl/rev/extra...] — exact format is device-specific.
        // We’ll capture raw payload and mark present when we receive a response for that module.

        let modules = moduleDiscoveryOrder.map { $0.rawValue }
        var remaining = Array(modules)
        var results: [UInt8: BoardState.ModuleInfo] = [:]

        let subject = PassthroughSubject<[UInt8: BoardState.ModuleInfo], MWError>()
        let notifyCancellable = wire.notifications().sink { _ in } receiveValue: { data in
            guard data.count >= 2 else { return }
            let moduleId = data[0]
            let registerId = data[1]
            guard registerId == READ_INFO_REGISTER else { return }

            // Module info payload is data[2...]
            let extra = data.dropFirst(2)
            // We don’t know exact encoding for implementation/revision here without full spec,
            // but C++ stores: present, implementation, revision, extra (vector of bytes).
            // We’ll mark present = true and set implementation/revision heuristically if present.
            let impl: Int32 = extra.count > 0 ? Int32(extra[0]) : -1
            let rev: UInt8 = extra.count > 1 ? extra[1] : 0
            let info = BoardState.ModuleInfo(present: true, implementation: impl, revision: rev, extra: Data(extra))
            results[moduleId] = info

            // Remove from remaining if present
            if let idx = remaining.firstIndex(of: moduleId) {
                remaining.remove(at: idx)
            }

            // If all commands have responses (or we’ve sent all and timed out), we can complete
            if remaining.isEmpty {
                subject.send(results)
                subject.send(completion: .finished)
            }
        }

        // Send commands sequentially
        func sendNext() {
            guard let next = remaining.first else {
                // No remaining; if no responses arrive, we complete after a short delay
                queue.asyncAfter(deadline: .now() + 0.5) {
                    subject.send(results)
                    subject.send(completion: .finished)
                }
                return
            }
            let packet = Data([next, READ_INFO_REGISTER])
            _ = wire.write(packet, expectsResponse: false).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            // Send next after a small pacing delay
            queue.asyncAfter(deadline: .now() + 0.02, execute: sendNext)
        }

        queue.async(execute: sendNext)

        // Timeout in case some modules don’t respond (mirror initialized_timeout behavior loosely)
        queue.asyncAfter(deadline: .now() + 4.0) {
            subject.send(results)
            subject.send(completion: .finished)
        }

        return subject
            .handleEvents(receiveCompletion: { _ in
                notifyCancellable.cancel()
            }, receiveCancel: {
                notifyCancellable.cancel()
            })
            .eraseToAnyPublisher()
    }

    // Internal hook for MetaWear to inform engine about MetaBoot status if needed
    func _setMetaBoot(_ value: Bool) {
        self.isMetaBoot = value
    }

    // Internal bridge for MetaWear
    func _didReceiveNotification(_ data: Data) {
        wire?._didReceiveNotification(data)
    }
}

// MARK: - Internal notification to funnel DIS reads
extension Notification.Name {
    static let MWInternalDidUpdateValue = Notification.Name("MWInternalDidUpdateValue")
}

