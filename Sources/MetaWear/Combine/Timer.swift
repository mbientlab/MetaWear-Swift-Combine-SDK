// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Readable Signal Timer

public extension Publisher where Output == (MetaWear, MWDataSignal) {

    /// Creates a timer on the MetaWear that reads the data signal provided.
    ///
    /// - Parameters:
    ///   - freq: Time between timer firing events
    /// - Returns: Tuple of the MetaWear, the event-triggered data signal, and the timer
    ///
    func createPollingTimer(freq: MWFrequency)
    -> MWPublisher<(metawear: MetaWear, counter: MWDataSignal, timer: MWDataSignal)> {
        let upstream = self.mapToMWError().share()
        let counter = upstream.flatMap { _, readableSignal in readableSignal.accounterCreateCount() }
        let timer = upstream.flatMap { metawear, readableSignal in
            metawear.board.createTimedEvent(
                period: UInt32(freq.periodMs),
                repetitions: .max,
                immediateFire: false,
                recordedEvent: { mbl_mw_datasignal_read(readableSignal) }
            )}

        return upstream.zip(counter, timer)
            .map { mw, counter, timer in (mw.0, counter, timer) }
            .share()
            .eraseToAnyPublisher()
    }
}

// MARK: - General Timers

public extension Publisher where Output == MetaWear {

    /// Creates a timer on the MetaWear that triggers the commands provided.
    /// If you want to read a signal, see `.createPollingTimer` on Publishers
    /// with an Output of `(MetaWear, MWDataSignal)`.
    ///
    /// - Parameters:
    ///   - period: Milliseconds between timer firing events
    ///   - repetitions: Times to repeat or `.max` for unlimited
    ///   - immediateFire: Trigger the timer eagerly, rather than explicitly by `mbl_mw_timer_start`
    ///   - commands: C++ commands such as reading a signal
    /// - Returns: Timer reference
    ///
    func createTimedEvent(period: UInt32,
                          repetitions: UInt16 = .max,
                          immediateFire: Bool = false,
                          recordedEvent commands: @escaping () -> Void
    ) -> MWPublisher<(metawear: MetaWear, timer: OpaquePointer)> {

        let upstream = self.mapToMWError().share()
        return upstream.flatMap { mw -> MWPublisher<(metawear: MetaWear, timer: OpaquePointer)> in
            upstream
                .zip(mw.board.createTimedEvent(
                    period: period,
                    repetitions: repetitions,
                    immediateFire: immediateFire,
                    recordedEvent: commands),
                     { ($0, $1) }
                ).erase(subscribeOn: mw.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Creates a timer on the MetaWear.
    /// If you want to read a signal, see `stream<P:MWPollable>`
    /// for an example using a counter to trigger signal reads.
    ///
    /// - Parameters:
    ///   - period: Milliseconds between timer firing events
    ///   - repetitions: Times to repeat or `.max` for unlimited
    ///   - immediateFire: Trigger the timer eagerly, rather than explicitly by `mbl_mw_timer_start`
    /// - Returns: Timer reference
    ///
    func createTimer(periodMs: UInt32,
                     repetitions: UInt16 = .max,
                     immediateFire: Bool = false
    ) -> MWPublisher<OpaquePointer> {

        mapToMWError()
            .flatMap { device -> MWPublisher<OpaquePointer> in
                device.board
                    .createTimer(period: periodMs, repetitions: repetitions, immediateFire: immediateFire)
                    .erase(subscribeOn: device.apiAccessQueue)
            }
            .eraseToAnyPublisher()
    }
}


public extension MWBoard {


    /// When pointing to a board, creates a timer. Combine interface to `mbl_mw_timer_create`.
    ///
    func createTimer(period: UInt32,
                     repetitions: UInt16 = .max,
                     immediateFire: Bool = false
    ) -> PassthroughSubject<OpaquePointer, MWError> {

        let subject = PassthroughSubject<OpaquePointer,MWError>()

        mbl_mw_timer_create(self, period, repetitions, immediateFire ? 0 : 1, bridge(obj: subject)) { (context, timer) in
            let _subject: PassthroughSubject<OpaquePointer, MWError> = bridge(ptr: context!)

            if let timer = timer {
                _subject.send(timer)
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not create timer")))
            }
        }
        return subject
    }

    /// When pointing to a board, creates a timer. Combine interface to `mbl_mw_timer_create`, `mbl_mw_event_record_commands`, and `mbl_mw_event_end_record`.
    ///
    func createTimedEvent(period: UInt32,
                          repetitions: UInt16 = .max,
                          immediateFire: Bool = false,
                          recordedEvent commands: @escaping () -> Void
    ) -> AnyPublisher<MWDataSignal, MWError> {

        createTimer(period: period, repetitions: repetitions, immediateFire: immediateFire)
            .flatMap { timer -> MWPublisher<OpaquePointer> in
                mbl_mw_event_record_commands(timer)
                commands()
                return Publishers.Zip(_JustMW(timer), timer.eventEndRecording())
                    .map(\.0)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// When pointing to a board, ends recording of an `MblMwEvent`. Combine wrapper for `mbl_mw_event_end_record`.
    ///
    func eventEndRecording() -> PassthroughSubject<Void,MWError> {

        let subject = PassthroughSubject<Void,MWError>()
        mbl_mw_event_end_record(self, bridge(obj: subject)) { (context, event, status) in
            let _subject: PassthroughSubject<Void,MWError> = bridge(ptr: context!)

            guard status == MWStatusCode.ok.cppValue else {
                let code = MWStatusCode(cpp: status)?.rawValue ?? "Unknown code"
                let msg = "Event end record failed: \(code)"
                _subject.send(completion: .failure(.operationFailed(msg)))
                return
            }
            _subject.send()
            _subject.send(completion: .finished)
        }
        return subject
    }
}
