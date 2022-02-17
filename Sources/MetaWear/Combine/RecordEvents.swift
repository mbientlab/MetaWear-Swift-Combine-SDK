// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// For timed events, see Timer.swift.

public extension Publisher where Output == MetaWear {

    /// Record commands to execute upon a trigger, such as a sensor signal after a logic computation. An example is triggering the LED and sensor recording upon button press/release. The default options include on even or odd button presses or upon button release or depress.
    ///
    /// If you wish to respond to custom scenarios, use `recordEventsForOpaqueSignal(:)`. While it shares the same recording closure as `recordEvents`, it requires you to have already prepared the data processor signal, emitting it as the second element in a tuple with a ``MetaWear/MetaWear``. For example code, see the SDK source for `recordEvents`, which waits for preset data processor signals to construct before calling `recordEventsForOpaqueSignal`. For example preparation of data processors, see ``MetaWear/MWEventSignal/signal(_:)``.
    ///
    /// This command differs from a macro formed by ``MWCommand/macroStartRecording(runOnStartup:)``. A macro is triggered (a) on every reboot or (b) by your explicit command via its identifier. A macro can include several `recordEvents` commands to ensure they restore on reboot.
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
        let presetDataProcessorSignal = signal.signal(upstream)
        return upstream
        // Wait until the preset data processor is constructed.
            .zip(presetDataProcessorSignal, { (device: $0, signal: $1) })
        // Pass the tuple (MetaWear, OpaquePointer) to the public utility function for recording any data processor signal.
            .recordEventsForOpaqueSignal(events)
    }
}

public enum MWEventSignal {
    /// When the button is pressed
    case buttonDown
    /// When the button is released
    case buttonUp
    /// On the 2nd, 4th, etc. button releases
    case buttonPressEvens
    /// On the 1st, 3rd, etc. button releases
    case buttonPressOdds

    /// Constructs data processor signals asynchronously
    public func signal(_ upstream: MWPublisher<MetaWear>) -> MWPublisher<MWDataProcessorSignal> {
        switch self {
        case .buttonDown:
            let source = MWMechanicalButton()
            return upstream.map(\.board).flatMap(source.getDownEventSignal).eraseToAnyPublisher()

        case .buttonUp:
            let source = MWMechanicalButton()
            return upstream.map(\.board).flatMap(source.getUpEventSignal).eraseToAnyPublisher()

        case .buttonPressEvens:
            let source = MWEventSignal.buttonUp.signal(upstream)
            return source
                .counted(size: nil)
                .math(.modulus, rhs: 2)
                .filter(.equals, reference: 0)

        case .buttonPressOdds:
            let source = MWEventSignal.buttonUp.signal(upstream)
            return source
                .counted(size: nil)
                .math(.modulus, rhs: 2)
                .filter(.notEqualTo, reference: 0)
        }
    }
}

public extension Publisher where Output == (device: MetaWear, signal: MWDataProcessorSignal) {

    /// Record any commands (that you issue in the closure) for execution when the MetaWear receives an output from the provided signal.
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
