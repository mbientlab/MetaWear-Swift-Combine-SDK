import Foundation
import CoreBluetooth
import Combine

public protocol BoardEngine {
    // Called once we have the peripheral and characteristics
    func initialize(peripheral: CBPeripheral, commandChar: CBCharacteristic?, notifyChar: CBCharacteristic?, queue: DispatchQueue)

    // Full Swift initialization pipeline (parity with C++ initialize):
    // Enables notify (handled via setNotifyValue in MetaWear), reads DIS,
    // discovers modules by querying READ_INFO_REGISTER in the same order
    // as the C++ MODULE_DISCOVERY_CMDS, optionally reads logging time,
    // runs module init hooks, and returns BoardState.
    func startInitialization() -> AnyPublisher<BoardState, MWError>

    // Low-level write
    func send(_ data: Data, expectsResponse: Bool) -> AnyPublisher<Data?, MWError>

    // Raw notify payloads
    func notifications() -> AnyPublisher<Data, Never>
}

public final class NoopBoardEngine: BoardEngine {
    private let subject = PassthroughSubject<Data, Never>()
    public init() {}

    public func initialize(peripheral: CBPeripheral, commandChar: CBCharacteristic?, notifyChar: CBCharacteristic?, queue: DispatchQueue) {
        #if DEBUG
        print("[BoardEngine:Noop] initialize called with peripheral: \(peripheral.identifier), command: \(String(describing: commandChar?.uuid)), notify: \(String(describing: notifyChar?.uuid)), queue: \(queue.label)")
        #endif
        // no-op
    }

    public func startInitialization() -> AnyPublisher<BoardState, MWError> {
        #if DEBUG
        print("[BoardEngine:Noop] startInitialization called")
        #endif
        return Fail(error: MWError.operationFailed("Board engine not configured")).eraseToAnyPublisher()
    }

    public func send(_ data: Data, expectsResponse: Bool) -> AnyPublisher<Data?, MWError> {
        #if DEBUG
        print("[BoardEngine:Noop] send called ->", data as NSData, "expectsResponse:", expectsResponse)
        #endif
        return Fail<Data?, MWError>(error: MWError.operationFailed("Board engine not configured"))
            .eraseToAnyPublisher()
    }

    public func notifications() -> AnyPublisher<Data, Never> {
        #if DEBUG
        print("[BoardEngine:Noop] notifications publisher requested")
        #endif
        return subject.eraseToAnyPublisher()
    }
}

