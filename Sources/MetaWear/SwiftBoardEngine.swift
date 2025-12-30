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
    case ancs                  = 0x0e
    case macro                 = 0x0f
    case conductance           = 0x10
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
private let READ_COMMAND: UInt8 = 0x80

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
        #if DEBUG
        print("[Wire] init with peripheral: \(peripheral.identifier), commandChar: \(String(describing: commandChar?.uuid)), notifyChar: \(String(describing: notifyChar?.uuid)), queue: \(queue.label))")
        #endif
    }

    func update(commandChar: CBCharacteristic?, notifyChar: CBCharacteristic?) {
        #if DEBUG
        print("[Wire] update chars -> command: \(String(describing: commandChar?.uuid)), notify: \(String(describing: notifyChar?.uuid)))")
        #endif
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
                #if DEBUG
                print("[SwiftEngine] write:", data as NSData, "expectsResponse:", expectsResponse)
                #endif
                let type: CBCharacteristicWriteType = expectsResponse ? .withResponse : .withoutResponse
                self.peripheral.writeValue(data, for: commandChar, type: type)
                promise(.success(nil))
            }
        }
        .eraseToAnyPublisher()
    }

    func notifications() -> AnyPublisher<Data, Never> {
        #if DEBUG
        print("[Wire] notifications() publisher requested")
        #endif
        return notifySubject.eraseToAnyPublisher()
    }

    // Bridge from MetaWear.didUpdateValueFor
    func _didReceiveNotification(_ data: Data) {
        #if DEBUG
        print("[Wire] didReceiveNotification:", data as NSData)
        #endif
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
                #if DEBUG
                print("[Wire] DIS read request for \(uuid.uuidString)")
                #endif
                // One-shot observation via NotificationCenter
                let token = NotificationCenter.default.addObserver(forName: .MWInternalDidUpdateValue, object: self.peripheral, queue: nil) { note in
                    guard let info = note.userInfo as? [String: Any],
                          let ch = info["characteristic"] as? CBCharacteristic,
                          ch.uuid == uuid,
                          let data = ch.value else { return }
                    let str = String(data: data, encoding: .utf8) ?? ""
                    #if DEBUG
                    print("[Wire] DIS read response for \(uuid.uuidString): \(str)")
                    #endif
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

// MARK: - Module init hooks (scaffold)
private protocol ModuleInitializer {
    func initializeModule(_ moduleId: UInt8, info: BoardState.ModuleInfo, wire: MetaWearWire, queue: DispatchQueue)
}

// Registry to plug per-module initializers (fill these later)
private struct ModuleInitRegistry {
    static var initializers: [UInt8: ModuleInitializer] = [:]

    static func register(_ id: UInt8, initializer: ModuleInitializer) {
        initializers[id] = initializer
    }

    static func initializeIfPresent(moduleId: UInt8, info: BoardState.ModuleInfo, wire: MetaWearWire, queue: DispatchQueue) {
        guard info.present, let initr = initializers[moduleId] else { return }
        initr.initializeModule(moduleId, info: info, wire: wire, queue: queue)
    }
}

// Example no-op initializer for accelerometer (fill later)
// ModuleInitRegistry.register(ModuleID.accelerometer.rawValue, initializer: AccelerometerInitializer())

public final class SwiftBoardEngine: BoardEngine {
    private var wire: MetaWearWire?
    private var queue: DispatchQueue = .main

    // State during init
    private var isMetaBoot: Bool = false

    public init() {}

    public func initialize(peripheral: CBPeripheral, commandChar: CBCharacteristic?, notifyChar: CBCharacteristic?, queue: DispatchQueue) {
        #if DEBUG
        print("[SwiftEngine] initialize with peripheral: \(peripheral.identifier), queue: \(queue.label)")
        #endif
        self.queue = queue
        if let wire = wire {
            wire.update(commandChar: commandChar, notifyChar: notifyChar)
        } else {
            wire = MetaWearWire(peripheral: peripheral, commandChar: commandChar, notifyChar: notifyChar, queue: queue)
        }
        #if DEBUG
        print("[SwiftEngine] characteristics -> command: \(String(describing: commandChar?.uuid)), notify: \(String(describing: notifyChar?.uuid)))")
        #endif
    }

    public func notifications() -> AnyPublisher<Data, Never> {
        #if DEBUG
        print("[SwiftEngine] notifications() requested")
        #endif
        guard let wire = wire else { return Empty().eraseToAnyPublisher() }
        return wire.notifications()
    }

    public func send(_ data: Data, expectsResponse: Bool) -> AnyPublisher<Data?, MWError> {
        #if DEBUG
        print("[SwiftEngine] send:", data as NSData, "expectsResponse:", expectsResponse)
        #endif
        guard let wire = wire else {
            return Fail(outputType: Data?.self, failure: MWError.operationFailed("Board engine not configured")).eraseToAnyPublisher()
        }
        return wire.write(data, expectsResponse: expectsResponse)
    }

    // MARK: - Initialization pipeline (parity with C++)
    public func startInitialization() -> AnyPublisher<BoardState, MWError> {
        #if DEBUG
        print("[SwiftEngine] startInitialization")
        #endif
        guard let wire = wire else {
            return Fail(error: MWError.operationFailed("Board engine not configured")).eraseToAnyPublisher()
        }

        // 1) Read DIS in order: firmware -> model -> hardware -> manufacturer -> serial
        let firmware = wire.readDISString(DIS.firmware).replaceError(with: "").setFailureType(to: MWError.self)
        let model = wire.readDISString(DIS.model).replaceError(with: "").setFailureType(to: MWError.self)
        let hardware = wire.readDISString(DIS.hardware).replaceError(with: "").setFailureType(to: MWError.self)
        let manufacturer = wire.readDISString(DIS.manufacturer).replaceError(with: "").setFailureType(to: MWError.self)
        let serial = wire.readDISString(DIS.serial).replaceError(with: "").setFailureType(to: MWError.self)

        // Chain: DIS -> preliminary BoardState -> module discovery -> logging time -> module init hooks
        return firmware
            .combineLatest(model)
            .combineLatest(hardware)
            .combineLatest(manufacturer)
            .combineLatest(serial)
            .map { value -> BoardState in
                // Unpack nested combineLatest tuple: ((((fw, md), hw), mft), sn)
                let a = value.0          // ((fw, md), hw)
                let sn = value.1         // serial
                let b = a.0              // (fw, md)
                let mft = a.1            // manufacturer
                let c = b.0              // fw
                let hw = b.1             // hardware
                let fw = c.0             // firmware
                let md = c.1             // model
                #if DEBUG
                print("[SwiftEngine] DIS info -> fw: \(fw), model: \(md), hw: \(hw), mfr: \(mft), serial: \(sn)")
                #endif
                return BoardState(
                    isMetaBoot: self.isMetaBoot,
                    firmwareRevision: fw.isEmpty ? nil : fw,
                    hardwareRevision: hw.isEmpty ? nil : hw,
                    modelNumber: md.isEmpty ? nil : md,
                    manufacturerName: mft.isEmpty ? nil : mft,
                    serialNumber: sn.isEmpty ? nil : sn,
                    moduleInfo: [:]
                )
            }
            .flatMap { prelim -> AnyPublisher<BoardState, MWError> in
                // 2) Start module discovery only AFTER DIS and preliminary BoardState are ready
                #if DEBUG
                print("[SwiftEngine] starting module discovery after DIS")
                #endif
                return self.discoverModules()
                    .map { modules -> BoardState in
                        var state = prelim
                        state.moduleInfo = modules
                        return state
                    }
                    .eraseToAnyPublisher()
            }
            .flatMap { stateAfterDiscovery -> AnyPublisher<BoardState, MWError> in
                // 3) Optionally read logging time after discovery
                #if DEBUG
                print("[SwiftEngine] attempting logging time read after discovery")
                #endif
                return self.readLoggingTimeIfAvailable()
                    .map { logRef in
                        var s = stateAfterDiscovery
                        s.loggingTime = logRef
                        return s
                    }
                    .eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { [weak self] state in
                #if DEBUG
                print("[SwiftEngine] state assembled. modules: \(state.moduleInfo.count), loggingTime: \(String(describing: state.loggingTime))")
                #endif
                // 4) Run module init hooks
                guard let self, let wire = self.wire else { return }
                for (mid, info) in state.moduleInfo {
                    ModuleInitRegistry.initializeIfPresent(moduleId: mid, info: info, wire: wire, queue: self.queue)
                }
            })
            .eraseToAnyPublisher()
    }

    // MARK: - Module discovery (mirrors MODULE_DISCOVERY_CMDS + char_changed_handler)
    private func discoverModules() -> AnyPublisher<[UInt8: BoardState.ModuleInfo], MWError> {
        guard let wire = wire else {
            return Fail(error: MWError.operationFailed("Board engine not configured")).eraseToAnyPublisher()
        }
        #if DEBUG
        print("[SwiftEngine] discoverModules start. order: \(moduleDiscoveryOrder.map{ $0.rawValue })")
        #endif

        let modules = moduleDiscoveryOrder.map { $0.rawValue }
        var remaining = Array(modules)
        var results: [UInt8: BoardState.ModuleInfo] = [:]

        let subject = PassthroughSubject<[UInt8: BoardState.ModuleInfo], MWError>()
        let notifyCancellable = wire.notifications().sink { _ in } receiveValue: { data in
            guard data.count >= 2 else { return }
            let moduleId = data[0]
            // Only accept responses that start with a module id we still care about
            guard remaining.contains(moduleId) else { return }
            #if DEBUG
            let registerId = data[1]
            print("[SwiftEngine] module info response -> module: \(moduleId), register: \(registerId), bytes:", data as NSData)
            #endif

            // Body = data[2...]
            let body = ArraySlice(data.dropFirst(2))
            let info = Self.parseModuleInfo(body: body)
            results[moduleId] = info

            if let idx = remaining.firstIndex(of: moduleId) {
                remaining.remove(at: idx)
            }
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
                    #if DEBUG
                    print("[SwiftEngine] discoverModules timeout. results: \(results.keys.map{ $0 })")
                    #endif
                    subject.send(results)
                    subject.send(completion: .finished)
                }
                return
            }
            #if DEBUG
            print("[SwiftEngine] discover -> read info for module: \(next)")
            #endif
            let packet = Data([next, (READ_INFO_REGISTER | READ_COMMAND)])
            _ = wire.write(packet, expectsResponse: false).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            queue.asyncAfter(deadline: .now() + 0.02, execute: sendNext)
        }

        queue.async(execute: sendNext)

        // Timeout in case some modules don’t respond (mirror initialized_timeout loosely)
        queue.asyncAfter(deadline: .now() + 4.0) {
            #if DEBUG
            print("[SwiftEngine] discoverModules timeout. results: \(results.keys.map{ $0 })")
            #endif
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

    // Precise ModuleInfo parsing (robust to shorter payloads)
    private static func parseModuleInfo(body: ArraySlice<UInt8>) -> BoardState.ModuleInfo {
        let bytes = Array(body)
        #if DEBUG
        print("[SwiftEngine] parseModuleInfo bytes:", Data(bytes))
        #endif
        switch bytes.count {
        case 0:
            return .init(present: true, implementation: -1, revision: 0, extra: Data())
        case 1:
            return .init(present: true, implementation: Int32(bytes[0]), revision: 0, extra: Data())
        case 2:
            return .init(present: true, implementation: Int32(bytes[0]), revision: bytes[1], extra: Data())
        default:
            // Heuristic layout: [presentFlag, impl, rev, extra...]
            // If first byte seems a boolean flag (0/1), use it as present. Otherwise, assume present = true and treat first two as impl/rev.
            let presentFlag = (bytes[0] == 0 || bytes[0] == 1) ? (bytes[0] != 0) : true
            let implIndex = (bytes[0] == 0 || bytes[0] == 1) ? 1 : 0
            let revIndex = implIndex + 1
            let extraIndex = revIndex + 1
            let impl = (implIndex < bytes.count) ? Int32(bytes[implIndex]) : -1
            let rev: UInt8 = (revIndex < bytes.count) ? bytes[revIndex] : 0
            let extra = (extraIndex < bytes.count) ? Data(bytes[extraIndex...]) : Data()
            return .init(present: presentFlag, implementation: impl, revision: rev, extra: extra)
        }
    }

    // MARK: - Logging time signal (optional parity with C++)
    // NOTE: We need the exact read command bytes for the logging time data signal.
    // In C++ they call mbl_mw_logging_get_time_data_signal() then mbl_mw_datasignal_read(signal).
    // TODO: Replace `loggingTimeReadCommand` with the correct register/command bytes for your boards.
    private func readLoggingTimeIfAvailable() -> AnyPublisher<BoardState.LoggingTimeRef?, MWError> {
        guard let wire = wire else {
            return Just(nil).setFailureType(to: MWError.self).eraseToAnyPublisher()
        }
        #if DEBUG
        print("[SwiftEngine] readLoggingTimeIfAvailable -> sending read command")
        #endif

        // If logging module is not present, skip
        // We don’t have module map yet here; we’ll just try and timeout quickly.
        let loggingTimeReadCommand = Data([ModuleID.logging.rawValue, 0x00 /* TODO: replace with correct register id for logging time read */])

        let responseSubject = PassthroughSubject<BoardState.LoggingTimeRef?, Never>()
        var responseHandled = false

        let cancellable = wire.notifications().sink { _ in } receiveValue: { data in
            #if DEBUG
            print("[SwiftEngine] logging module notification:", data as NSData)
            #endif
            // Expect a response header for logging module; filter quickly
            guard data.count >= 2, data[0] == ModuleID.logging.rawValue else { return }
            // TODO: refine by register id if needed
            let body = data.dropFirst(2)
            if let ref = Self.parseLoggingTime(body: Array(body)) {
                responseHandled = true
                responseSubject.send(ref)
                responseSubject.send(completion: .finished)
            }
        }

        // Send the read command
        _ = wire.write(loggingTimeReadCommand, expectsResponse: false).sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        // Timeout after 500ms if no response
        queue.asyncAfter(deadline: .now() + 0.5) {
            if responseHandled == false {
                #if DEBUG
                print("[SwiftEngine] logging time read timeout")
                #endif
                responseSubject.send(nil)
                responseSubject.send(completion: .finished)
            }
        }

        return responseSubject
            .handleEvents(receiveCompletion: { _ in cancellable.cancel() },
                          receiveCancel: { cancellable.cancel() })
            .setFailureType(to: MWError.self)
            .eraseToAnyPublisher()
    }

    // Parse logging time payload (reset_uid + epoch). Layout depends on firmware.
    // Common layout: [reset_uid:4 bytes little-endian][epoch_ms:8 bytes little-endian]
    private static func parseLoggingTime(body: [UInt8]) -> BoardState.LoggingTimeRef? {
        #if DEBUG
        print("[SwiftEngine] parseLoggingTime bytes:", Data(body))
        #endif
        guard body.count >= 12 else { return nil }
        let resetUID = UInt32(littleEndian: body[0..<4].withUnsafeBytes { $0.load(as: UInt32.self) })
        let epochMs = Int64(littleEndian: body[4..<12].withUnsafeBytes { $0.load(as: Int64.self) })
        return .init(resetUID: resetUID, epochMs: epochMs)
    }

    // Internal hook for MetaWear to inform engine about MetaBoot status if needed
    func _setMetaBoot(_ value: Bool) {
        #if DEBUG
        print("[SwiftEngine] setMetaBoot -> \(value)")
        #endif
        self.isMetaBoot = value
    }

    // Internal bridge for MetaWear
    func _didReceiveNotification(_ data: Data) {
        #if DEBUG
        print("[SwiftEngine] _didReceiveNotification:", data as NSData)
        #endif
        wire?._didReceiveNotification(data)
    }
}

// MARK: - Internal notification to funnel DIS reads
extension Notification.Name {
    static let MWInternalDidUpdateValue = Notification.Name("MWInternalDidUpdateValue")
}

