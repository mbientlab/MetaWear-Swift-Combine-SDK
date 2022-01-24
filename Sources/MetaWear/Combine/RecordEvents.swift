// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// For timed events, see Timer.swift.

public extension Publisher where Output == MetaWear {

    /// Record commands to execute upon a trigger, such as a sensor signal after a logic computation. An example is triggering the LED and sensor recording upon button press/release.
    ///
    /// In English, this recording commands for an event sounds very much like a ``MWCommand/macroStartRecording(runOnStartup:)``. The difference is that a macro is triggered (a) by your explicit command via its identifier or (b) on every reboot. A macro can include this event recording to ensure it restores on reboot.
    ///
    /// - Parameters:
    ///   - signal: Trigger to respond to (e.g., button depressed or released)
    ///   - events: A pipeline to record desired events, such as flashing a light
    ///
    /// - Returns: MetaWear that recorded the event or an error
    ///
    func recordEvents(
        for signal: MWEventSignal,
        _ events: @escaping (MWPublisher<MetaWear>) -> MWPublisher<MetaWear>
    ) -> MWPublisher<MetaWear> {
        let upstream = mapToMWError().share().eraseToAnyPublisher()
        let cppSignal = signal.signal(upstream)
        return upstream
            .zip(cppSignal, { (device: $0, signal: $1) })
            .recordEventsForOpaqueSignal(events)
    }
}

public enum MWEventSignal {
    case buttonDown, buttonUp

    public func signal(_ upstream: MWPublisher<MetaWear>) -> MWPublisher<MWDataProcessorSignal> {
        switch self {
            case .buttonDown:
                let source = MWMechanicalButton()
                return upstream.map(\.board).flatMap(source.getDownEventSignal).eraseToAnyPublisher()
            case .buttonUp:
                let source = MWMechanicalButton()
                return upstream.map(\.board).flatMap(source.getUpEventSignal).eraseToAnyPublisher()
        }
    }
}

public extension Publisher where Output == (device: MetaWear, signal: MWDataProcessorSignal) {

    /// Record any commands issued in the closure to execute when the MetaWear receives an output from the provided signal.
    ///
    /// - Parameter events: A pipeline to record desired events, such as flashing a light
    /// - Returns: MetaWear that recorded the event or an error
    ///
    func recordEventsForOpaqueSignal(
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
