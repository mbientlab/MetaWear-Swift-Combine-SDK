// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// For timed events, see Timer.swift.

public extension Publisher where Output == MetaWear {

    /// Record any commands issued in the closure to execute when the MetaWear's button is depressed.
    ///
    /// - Parameter events: A pipeline to record desired events, such as flashing a light
    /// - Returns: MetaWear that recorded the event or an error
    ///
    func recordEventsOnButtonDown(
        _ events: @escaping (MWPublisher<MetaWear>) -> MWPublisher<MetaWear>
    ) -> MWPublisher<MetaWear> {
        let upstream = mapToMWError().share()
        let source = MWMechanicalButton()
        let signal = upstream.map(\.board).flatMap(source.getDownEventSignal)
        return upstream
            .zip(signal, { (device: $0, signal: $1) })
            .recordEventsForSignal(events)
    }

    /// Record any commands issued in the closure to execute when the MetaWear's button is released.
    ///
    /// - Parameter events: A pipeline to record desired events, such as flashing a light
    /// - Returns: MetaWear that recorded the event or an error
    ///
    func recordEventsOnButtonUp(
        _ events: @escaping (MWPublisher<MetaWear>) -> MWPublisher<MetaWear>
    ) -> MWPublisher<MetaWear> {
        let upstream = mapToMWError().share()
        let source = MWMechanicalButton()
        let signal = upstream.map(\.board).flatMap(source.getUpEventSignal)
        return upstream
            .zip(signal, { (device: $0, signal: $1) })
            .recordEventsForSignal(events)
    }
}

public extension Publisher where Output == (device: MetaWear, signal: MWDataProcessorSignal) {

    /// Record any commands issued in the closure to execute when the MetaWear receives an output from the provided signal.
    ///
    /// - Parameter events: A pipeline to record desired events, such as flashing a light
    /// - Returns: MetaWear that recorded the event or an error
    ///
    func recordEventsForSignal(
        _ events: @escaping (MWPublisher<MetaWear>) -> MWPublisher<MetaWear>
    ) -> MWPublisher<MetaWear> {
        let upstream = self.mapToMWError().share()
        let userInput = events(upstream.map(\.device).eraseToAnyPublisher())
        return upstream
            .handleEvents(receiveOutput: { mw, event in
                mbl_mw_event_record_commands(event)
            })
            .zip(userInput, { (event: $0.signal, device: $1) })
            .flatMap { event, device -> MWPublisher<MetaWear> in
                event
                    .eventEndRecording()
                    .map { device }
                    .erase(subscribeOn: device.bleQueue)
            }
            .eraseToAnyPublisher()
    }
}

public extension MWBoard {

    /// When pointing to an event signal, ends recording of an `MblMwEvent`.
    ///
    /// Combine wrapper for `mbl_mw_event_end_record`.
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
