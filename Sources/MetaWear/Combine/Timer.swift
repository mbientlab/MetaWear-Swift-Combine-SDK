// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Readable Signal Timer

public extension Publisher where Output == (MetaWear, MWDataSignal) {

    /// Creates a timer on the MetaWear that reads the data signal provided for streaming.
    ///
    /// - Parameters:
    ///   - freq: Time between timer firing events
    /// - Returns: Tuple of the MetaWear, the event-triggered data signal, and the timer
    ///
    func createPollingTimer(freq: MWFrequency)
    -> MWPublisher<(metawear: MetaWear, counter: MWDataSignal, timer: MWTimerSignal)> {
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
    /// with an Output of `(MetaWear, MWTimerSignal)`. Useful for logging pollable events.
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
    ) -> MWPublisher<MWTimerSignal> {
        mapToMWError()
            .flatMap { mw -> MWPublisher<MWTimerSignal> in
                mw.board.createTimedEvent(
                    period: period,
                    repetitions: repetitions,
                    immediateFire: immediateFire,
                    recordedEvent: commands
                ).erase(subscribeOn: mw.bleQueue)
            }
            .eraseToAnyPublisher()
    }

    /// Creates a timer on the MetaWear.
    /// If you want to read a signal, see `stream<P:MWPollable>`
    /// and `log<P:MWPollable>` for examples of triggering signal reads.
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
    ) -> MWPublisher<MWTimerSignal> {

        mapToMWError()
            .flatMap { device -> MWPublisher<MWTimerSignal> in
                device.board
                    .createTimer(period: periodMs, repetitions: repetitions, immediateFire: immediateFire)
                    .erase(subscribeOn: device.bleQueue)
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
    ) -> PassthroughSubject<MWTimerSignal, MWError> {

        let subject = PassthroughSubject<MWTimerSignal,MWError>()

        mbl_mw_timer_create(self, period, repetitions, immediateFire ? 0 : 1, bridge(obj: subject)) { (context, timer) in
            let _subject: PassthroughSubject<MWTimerSignal, MWError> = bridge(ptr: context!)

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
    ) -> AnyPublisher<MWTimerSignal, MWError> {

        createTimer(period: period, repetitions: repetitions, immediateFire: immediateFire)
            .flatMap { timer -> MWPublisher<MWTimerSignal> in
                Swift.print("-> mbl_mw_event_record_commands", #function)
                mbl_mw_event_record_commands(timer)
                commands()
                return Publishers.Zip(_JustMW(timer), timer.eventEndRecording())
                    .map(\.0)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
