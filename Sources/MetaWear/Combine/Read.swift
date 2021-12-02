// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp


// MARK: - Read Once

public extension Publisher where Output == MetaWear {

    /// Performs a one-time read of a board signal, handling C++ library calls, pointer bridging, and returned data type casting.
    ///
    /// - Parameters:
    ///   - signal: Type-safe preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func read<R: MWReadable>(_ readable: R) -> MWPublisher<Timestamped<R.DataType>> {
        tryMap { metawear -> (metawear: MetaWear, signal: OpaquePointer) in
            guard let signalPointer = try readable.readableSignal(board: metawear.board)
            else { throw MWError.operationFailed("Board unavailable for \(readable.name).") }
            readable.readConfigure(board: metawear.board)
            return (metawear, signalPointer)
        }
        .mapToMetaWearError()
        .flatMap { metawear, signalPointer -> MWPublisher<Timestamped<R.DataType>> in
            signalPointer
                .read(readable)
                .handleEvents(receiveOutput: { _ in readable.readCleanup(board: metawear.board) })
                .mapError { _ in // Replace any unspecific type casting failure message
                    MWError.operationFailed("Failed reading \(readable.name).")
                }
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Performs a one-time read of a board signal, handling pointer bridging, and casting to the provided type.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_settings_get_battery_state_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func read<T>(signal: OpaquePointer, as type: T.Type) -> MWPublisher<Timestamped<T>> {
        mapToMetaWearError()
            .flatMap { metawear in
                metawear.board
                    .read(as: T.self)
                    .erase(subscribeOn: metawear.apiAccessQueue)
            }
            .eraseToAnyPublisher()
    }
}

public extension MWDataSignal {

    /// When pointing to a data signal, perform a one-time read. Call clean up or configure methods yourself.
    ///
    func read<R: MWReadable>(_ readable: R) -> AnyPublisher<Timestamped<R.DataType>, MWError> {
        _read()
            .map(readable.convertRawToSwift)
            .mapError { _ in // Replace a generic read error (C function pointer cannot form w/ generic)
                MWError.operationFailed("Could not read \(R.DataType.self)")
            }
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, perform a one-time read. Call clean up or configure methods yourself.
    ///
    /// Performs:
    ///   - `mbl_mw_datasignal_subscribe`
    ///   - `dataPtr.pointee.copy` -> ensures lifetime extends beyond closure
    ///   - `.valueAs` casts from `MetaWearData`
    ///   - `mbl_mw_datasignal_read`
    ///   - `mbl_mw_datasignal_unsubscribe` (on cancel or completion)
    ///
    func read<T>(as: T.Type) -> AnyPublisher<Timestamped<T>, MWError> {
        _read()
            .map { ($0.timestamp, $0.valueAs() as T) }
            .mapError { _ in // Replace a generic read error (C function pointer cannot form w/ generic)
                MWError.operationFailed("Could not read \(T.self)")
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Internal

private extension MWDataSignal {
    func _read() -> AnyPublisher<MWData, MWError> {

        assert(mbl_mw_datasignal_is_readable(self) != 0)
        let subject = _datasignal_subscribe_outputOnlyOnce(self)
        mbl_mw_datasignal_read(self)

        return subject
            .handleEvents(receiveCompletion: { completion in
                mbl_mw_datasignal_unsubscribe(self)
            }, receiveCancel: {
                mbl_mw_datasignal_unsubscribe(self)
            })
            .eraseToAnyPublisher()
    }
}
