// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Stream (Presets)

public extension Publisher where Output == MetaWear {

    /// Stream time-stamped data from the MetaWear board using a type-safe preset (with optional configuration).
    ///
    /// - Parameters:
    ///   - signal: Type-safe, configurable preset for `MetaWear` board signals
    ///
    /// - Returns: Time-stamped sensor data
    ///
    func stream<S: MWStreamable>(_ streamable: S) -> MWPublisher<Timestamped<S.DataType>> {

        tryMap { metaWear -> (metawear: MetaWear, signal: MWDataSignal) in
            streamable.streamConfigure(board: metaWear.board)
            guard let pointer = try streamable.streamSignal(board: metaWear.board) else {
                throw MWError.operationFailed("Signal unavailable for \(streamable.name).")
            }
            return (metawear: metaWear, signal: pointer)
        }
        .mapToMetaWearError()
        .flatMap { o -> MWPublisher<Timestamped<S.DataType>> in
            o.signal.stream(streamable, board: o.metawear.board)
                .erase(subscribeOn: o.metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// "Streams" a read-only signal preset at a regular interval.
    ///
    /// - Returns: Time-stamped sensor data
    ///
    func stream<P: MWPollable>(_ pollable: P) -> MWPublisher<Timestamped<P.DataType>> {
        tryMap { metawear -> (metawear: MetaWear, sensor: MWDataSignal) in
            guard let moduleSignal = try pollable.pollSensorSignal(board: metawear.board)
            else { throw MWError.operationFailed("Could not create \(pollable.name)") }
            pollable.pollConfigure(board: metawear.board)
            return (metawear, moduleSignal)
        }
        .mapToMetaWearError()
        .flatMap { o -> MWPublisher<MWData> in
            _poll(
                polling: o.sensor,
                rate: pollable.pollingRate,
                cleanup: { pollable.pollCleanup(board: o.metawear.board) }
            )
        }
        .map(pollable.convertRawToSwift)
        .eraseToAnyPublisher()
    }
}

// MARK: - Stream (Manual)

public extension Publisher where Output == MetaWear {

    /// Requires some knowledge of the C++ library and unsafe Swift. Convenience publisher for a streaming board signal.
    ///
    /// - Parameters:
    ///   - signal: A configured board signal produced by a C++ bridge command like `mbl_mw_acc_bosch_get_acceleration_data_signal(board)` after any configuration commmands
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `        mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - cleanup: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<T>(signal: MWDataSignal,
                   as type: T.Type,
                   start: (() -> Void)?,
                   cleanup: (() -> Void)?
    ) -> MWPublisher<Timestamped<T>> {

        mapToMetaWearError()
            .flatMap { metawear -> MWPublisher<Timestamped<T>> in
                signal
                    .stream(as: type, start: start, cleanup: cleanup)
                    .erase(subscribeOn: metawear.apiAccessQueue)
            }
            .eraseToAnyPublisher()
    }


    /// "Streams" a read-only signal at the interval provided.
    /// - Parameters:
    ///   - readableSignal: Configured sensor signal that can be read by `mbl_mw_datasignal_read`
    ///   - periodMs: Milliseconds between poll events
    ///   - as: Type to cast the data
    /// - Returns: Stream of timestamped, cast data from the polled signal
    ///
    func stream<T>(polling readableSignal: MWDataSignal,
                   rate: MWFrequency,
                   as type: T.Type,
                   cleanup: (() -> Void)?
    ) -> MWPublisher<Timestamped<T>> {

        _poll(polling: readableSignal, rate: rate, cleanup: cleanup)
            .map { ($0.timestamp, $0.valueAs() as T) }
            .eraseToAnyPublisher()
    }
}

// MARK: - Stream Base Methods

public extension Publisher where Output == MetaWear {

    /// "Streams" a read-only signal at the interval provided.
    ///
    /// - Parameters:
    ///   - readableSignal: Configured sensor signal that can be read by `mbl_mw_datasignal_read`
    ///   - periodMs: Milliseconds between poll events
    /// - Returns: Stream of data from the polled signal
    ///
    func _poll(polling readableSignal: MWDataSignal,
               rate: MWFrequency,
               cleanup: (() -> Void)?
    ) -> MWPublisher<MWData> {
        mapToMetaWearError()
            .flatMap { metawear -> MWPublisher<(metawear: MetaWear, countedSensor: MWDataSignal, timer: MWDataSignal)> in
                mapToMetaWearError()
                    .zip(readableSignal.accounterCreateCount(),
                         metawear.board.createTimedEvent(
                            period: UInt32(rate.periodMs),
                            repetitions: .max,
                            immediateFire: false,
                            recordedEvent: { mbl_mw_datasignal_read(readableSignal) }
                         )
                    ) { ($0, $1, $2) }.eraseToAnyPublisher()
            }
            .flatMap { o -> MWPublisher<MWData> in

                let data = _datasignal_subscribe(o.countedSensor)
                mbl_mw_timer_start(o.timer)

                let stop = {
                    mbl_mw_timer_stop(o.timer)
                    mbl_mw_timer_remove(o.timer)
                    mbl_mw_datasignal_unsubscribe(o.countedSensor)
                    cleanup?()
                }

                return data
                    .handleEvents(receiveCompletion: { _ in stop() }, receiveCancel: stop)
                    .erase(subscribeOn: o.metawear.apiAccessQueue)
            }
            .eraseToAnyPublisher()
    }
}

public extension MWDataSignal {

    /// When pointing to a data signal, start streaming the signal.
    ///
    func stream<S: MWStreamable>(_ streamable: S, board: MWBoard) -> AnyPublisher<Timestamped<S.DataType>, MWError> {
        _stream(
            start: { streamable.streamStart(board: board) },
            cleanup: { streamable.streamCleanup(board: board) }
        )
            .mapError { _ in // Replace a generic stream error
                MWError.operationFailed("Could not stream \(S.DataType.self)")
            }
            .map(streamable.convertRawToSwift)
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, start streaming the signal.
    ///
    /// Performs:
    ///   - Handler execution
    ///   - `mbl_mw_datasignal_subscribe`
    ///   - On cancel: `mbl_mw_datasignal_unsubscribe`
    ///
    /// - Parameters:
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    func stream<T>(as:      T.Type,
                   start:   (() -> Void)?,
                   cleanup: (() -> Void)?
    ) -> AnyPublisher<Timestamped<T>, MWError> {
        _stream(start: start, cleanup: cleanup)
            .mapError { _ in // Replace a generic stream error
                MWError.operationFailed("Could not stream \(T.self)")
            }
            .map { ($0.timestamp, $0.valueAs() as T) }
            .eraseToAnyPublisher()
    }

    private func _stream(start:   (() -> Void)?,
                         cleanup: (() -> Void)?
    ) -> AnyPublisher<MWData, MWError> {

        let subject = _datasignal_subscribe(self)
        start?()

        return subject
            .handleEvents(receiveCompletion: { completion in
                cleanup?()
                mbl_mw_datasignal_unsubscribe(self)
            }, receiveCancel: {
                cleanup?()
                mbl_mw_datasignal_unsubscribe(self)
                subject.send(completion: .finished)
            })
            .eraseToAnyPublisher()
    }
}
