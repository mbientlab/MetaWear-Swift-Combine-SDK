//
//  BoardEngine.swift
//  MetaWear
//
//  Created by Laura Kassovic on 12/26/25.
//

import Foundation
import CoreBluetooth
import Combine

public protocol BoardEngine {
    // Called once we have the peripheral and characteristics
    func initialize(peripheral: CBPeripheral, commandChar: CBCharacteristic?, notifyChar: CBCharacteristic?, queue: DispatchQueue)

    // Full Swift initialization pipeline (parity with C++ initialize)
    // Enables notify (handled via setNotifyValue in MetaWear), reads DIS,
    // discovers modules by querying READ_INFO_REGISTER in the same order
    // as the C++ MODULE_DISCOVERY_CMDS, and returns BoardState.
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
        // no-op
    }

    public func startInitialization() -> AnyPublisher<BoardState, MWError> {
        return Fail(error: MWError.operationFailed("Board engine not configured")).eraseToAnyPublisher()
    }

    public func send(_ data: Data, expectsResponse: Bool) -> AnyPublisher<Data?, MWError> {
        return Fail<Data?, MWError>(error: MWError.operationFailed("Board engine not configured"))
            .eraseToAnyPublisher()
    }

    public func notifications() -> AnyPublisher<Data, Never> {
        subject.eraseToAnyPublisher()
    }
}
