// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Toggle Lazy Logging

public extension Publisher where Output == MetaWear {

    /// Starts recording data for all loggers currently setup.
    ///
    /// You do not need to call this function unless
    /// (a) you setup loggers lazily by passing `false` for the `startImmediately` parameter or
    /// (b) you asked loggers to pause with `.loggingPause()`.
    ///
    /// If sensors are not powered on and configured, starting logging won't record data.
    /// Using the ``MWCommand/powerDownSensors`` requires manually calling
    /// ``MWLoggable/loggerConfigure(board:)-6w0ys`` and ``MWLoggable/loggerStart(board:)-elqf``
    /// functions to power the sensors up again. Or, remove the loggers and issue a new log command.
    ///
    /// - Parameters:
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///
    /// - Returns: The connected MetaWear.
    ///
    func loggersStart(overwriting: Bool = false) -> MWPublisher<MetaWear> {
        handleOutputOnBleQueue { mw in
            mbl_mw_logging_start(mw.board, overwriting ? 1 : 0)
        }
    }

    /// Stops recording data from all loggers, but doesn't destroy them.
    /// Sensors remain active.
    ///
    /// The gyroscope can consume a full battery in hours, so follow with
    /// a `.command` to stop all sensor activity if you do not plan on
    /// resuming logging in the near feature.
    ///
    /// - Returns: The connected MetaWear.
    ///
    func loggersPause() -> MWPublisher<MetaWear> {
        handleOutputOnBleQueue { mw in
            mbl_mw_logging_stop(mw.board)
        }
    }
}

// MARK: - Log Traditional Sensors

public extension Publisher where Output == MetaWear {

    /// Logs a preset sensor configuration (with optional data processing).
    ///
    /// - Parameters:
    ///   - loggable: Instance of a sensor configuration that supports logging its signal to onboard storage
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///   - startsImmediately: Start logging immediately upon issuing this command
    ///   - afterProcessing: Mutate the loggable signal by applying onboard `data_processor` functions (e.g., throttle)
    ///
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func log<L: MWLoggable>(
        _ loggable: L,
        overwriting: Bool = false,
        startImmediately: Bool = true,
        afterProcessing processing: ((MWPublisher<MWDataSignal>) -> MWPublisher<MWDataSignal>)? = nil
    ) -> MWPublisher<MetaWear> {

        let upstream = self.mapToMWError().share().eraseToAnyPublisher()
        let sensor = upstream.getLoggerMutablePointer(loggable)
        let signal = processing == nil ? sensor : processing!(sensor)

        return upstream
            .zip(signal) { ($0, $1) }
            .mapToMWError()
            .logPointer(overwriting: overwriting,
                        startImmediately: startImmediately,
                        start: { loggable.loggerStart(board: $0.board) } )
            .replaceMWError(.operationFailed("Unable to log \(loggable.name)"))
            .share()
            .eraseToAnyPublisher()
    }

    /// Given a non-nil preset, starts logging a preset sensor configuration.
    ///
    /// - Parameters:
    ///   - loggable: Instance of a sensor configuration that supports logging its signal to onboard storage
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///   - startsImmediately: Start logging immediately upon issuing this command
    ///   - afterProcessing: Mutate the loggable signal by applying onboard `data_processor` functions (e.g., throttle)
    ///
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func optionallyLog<L: MWLoggable>(
        _ loggable: L?,
        overwriting: Bool = false,
        startsImmediately: Bool = true,
        afterProcessing: ((MWPublisher<MWDataSignal>) -> MWPublisher<MWDataSignal>)? = nil
    ) -> MWPublisher<MetaWear> {

        if let loggable = loggable {
            return self.log(loggable, overwriting: overwriting, startImmediately: startsImmediately, afterProcessing: afterProcessing)
        } else { return self.mapToMWError() }
    }


    /// Returns a configured logger signal for applying onboard data processors and direct logging using `.logPointer`.
    ///
    func getLoggerMutablePointer<L: MWLoggable>(_ loggable: L) -> MWPublisher<MWDataSignal> {
        tryMap { mw -> (OpaquePointer) in
            loggable.loggerConfigure(board: mw.board)
            guard let signal = try loggable.loggerDataSignal(board: mw.board)
            else { throw MWError.operationFailed("Unable to make logger for \(loggable.name)") }
            return signal
        }
        .mapToMWError()
    }
}


// MARK: - Log Pollable Sensors

public extension Publisher where Output == MetaWear {

    /// Logs a preset sensor configuration that works by polling a readable signal.
    ///
    /// - Parameters:
    ///   - byPolling: Instance of a sensor configuration that supports logging its signal to onboard storage by polling at a specific interval
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///   - startsImmediately: Start logging immediately upon issuing this command
    ///
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func log<P: MWPollable>(
        byPolling pollable: P,
        overwriting: Bool = false,
        startsImmediately: Bool = true
    ) -> MWPublisher<MetaWear> {

        tryMap { metawear -> (metawear: MetaWear, sensor: MWDataSignal) in
            guard let moduleSignal = try pollable.pollSensorSignal(board: metawear.board)
            else { throw MWError.operationFailed("Could not create \(pollable.name)") }
            pollable.pollConfigure(board: metawear.board)
            return (metawear, moduleSignal)
        }
        .mapToMWError()
        .flatMap { o -> MWPublisher<MetaWear> in
            log(byPolling: o.sensor, rate: pollable.pollingRate, overwriting: overwriting)
                .replaceMWError(.operationFailed("Unable to log \(pollable.name)"))
                .erase(subscribeOn: o.metawear.bleQueue)
        }
        .share()
        .eraseToAnyPublisher()
    }


    /// Logs a sensor that can only be intermittently read (e.g., thermistors) at the intervals specified.
    ///
    /// - Parameters:
    ///   - byPolling: A data signal that supports logging by polling at a specific interval
    ///   - rate: Frequency at which to poll the sensor
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///   - startsImmediately: Start logging immediately upon issuing this command
    ///
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func log(byPolling signal: MWDataSignal,
             rate: MWFrequency,
             overwriting: Bool = false,
             startsImmediately: Bool = true
    ) -> MWPublisher<MetaWear> {

        let upstream = self.mapToMWError().share()
        return upstream
            .flatMap { metawear -> MWPublisher<MetaWear> in
                signal
                    .generateIdentifiableLoggerSignal()
                    .compactMap { [weak metawear] _ in metawear }
                    .eraseToAnyPublisher()
            }
            .flatMap { metawear -> MWPublisher<MetaWear> in
                metawear.board
                    .createTimedEvent(
                        period: UInt32(rate.periodMs),
                        repetitions: .max,
                        immediateFire: false,
                        recordedEvent: { mbl_mw_datasignal_read(signal) }
                    )
                    .handleEvents(receiveOutput: { timer in
                        if startsImmediately { mbl_mw_logging_start(metawear.board, overwriting ? 1 : 0) }
                        mbl_mw_timer_start(timer)
                    })
                    .compactMap { [weak metawear] _ in metawear }
                    .erase(subscribeOn: metawear.bleQueue)
            }
            .eraseToAnyPublisher()
    }


    /// Given a non-nil preset, starts logging a preset sensor configuration that works by polling a readable signal.
    ///
    /// - Parameters:
    ///   - byPolling: Instance of a sensor configuration that supports logging its signal to onboard storage by polling at a specific interval
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///   - startsImmediately: Start logging immediately upon issuing this command
    ///
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func optionallyLog<P: MWPollable>(
        byPolling pollable: P?,
        overwriting: Bool = false,
        startsImmediately: Bool = true
    ) -> MWPublisher<MetaWear> {

        if let pollable = pollable {
            return self.log(byPolling: pollable, overwriting: overwriting)
        } else { return self.mapToMWError() }
    }
}


// MARK: - Log Data Signal Pointers

public extension Publisher where Output == (MetaWear, MWDataSignal), Failure == MWError {

    /// When receiving a MetaWear and a configured (and possibly data processed) loggable data signal, this method starts logging the signal.
    ///
    /// - Parameters:
    ///   - board: Pointer to the MetaWear's board
    ///   - overwriting: Whether to overwrite existing data
    ///   - start: Block to start the given data signal's sensor(s)
    ///
    func logPointer(
        overwriting: Bool,
        startImmediately: Bool,
        start: ((MetaWear) -> Void)?
    ) -> MWPublisher<MetaWear> {
        flatMap { (metawear, signal) in
            signal
                .logPointer(
                    board: metawear.board,
                    overwriting: overwriting,
                    startImmediately: startImmediately,
                    start: { start?(metawear) }
                )
                .compactMap { [weak metawear] _ in metawear }
                .erase(subscribeOn: metawear.bleQueue)
        }
        .eraseToAnyPublisher()
    }
}

public extension Publisher where Output == MWDataSignal {

    /// When receiving a configured data signal, including from data processors, this method starts logging, returning a pointer to the logger signal with a typed identifier. Combine interface for `mbl_mw_datasignal_log`, `mbl_mw_logger_generate_identifier`, and `mbl_mw_logging_start`.
    ///
    /// - Parameters:
    ///   - board: Pointer to the MetaWear's board
    ///   - overwriting: Whether to overwrite existing data
    /// - Returns: Logger identifier and reference
    ///
    func logUpstreamPointer<L: MWLoggable>(
        ofType loggable: L,
        board: MWBoard,
        overwriting: Bool,
        startImmediately: Bool
    ) -> AnyPublisher<(id: MWNamedSignal, signal: OpaquePointer), MWError> {

        logUpstreamPointer(board: board, overwriting: overwriting, startImmediately: startImmediately,
                           start: { loggable.loggerStart(board: board) })
    }

    /// When receiving a configured data signal, including from data processors, this method starts logging, returning a pointer to the logger signal with a typed identifier. Combine interface for `mbl_mw_datasignal_log`, `mbl_mw_logger_generate_identifier`, and `mbl_mw_logging_start`.
    ///
    /// - Parameters:
    ///   - board: Pointer to the MetaWear's board
    ///   - overwriting: Whether to overwrite existing data
    ///   - start: Block to start the given data signal's sensor(s)
    /// - Returns: Logger identifier and reference
    ///
    func logUpstreamPointer(
        board: MWBoard,
        overwriting: Bool,
        startImmediately: Bool,
        start: (() -> Void)?
    ) -> AnyPublisher<(id: MWNamedSignal, signal: OpaquePointer), MWError> {

        mapToMWError()
            .flatMap { signal -> AnyPublisher<(id: MWNamedSignal, signal: OpaquePointer), MWError> in
                signal.logPointer(board: board, overwriting: overwriting, startImmediately: startImmediately, start: start)
            }
            .eraseToAnyPublisher()
    }
}

public extension MWDataSignal {

    /// When pointing to a data signal, starts logging after obtaining the logger's signal, returning a pointer to the logger signal with a typed identifier. Combine interface for `mbl_mw_datasignal_log`, `mbl_mw_logger_generate_identifier`, and `mbl_mw_logging_start`.
    ///
    /// - Parameters:
    ///   - board: Pointer to the MetaWear's board
    ///   - overwriting: Whether to overwrite existing data
    ///   - start: Block to start the given data signal's sensor(s)
    /// - Returns: Logger identifier and reference
    ///
    func logPointer(
        board:       MWBoard,
        overwriting: Bool,
        startImmediately: Bool,
        start:       (() -> Void)?
    ) -> AnyPublisher<(id: MWNamedSignal, signal: OpaquePointer), MWError> {

        generateIdentifiableLoggerSignal()
            .map { (MWNamedSignal(identifier: $0), $1) }
            .handleEvents(receiveOutput: { id, signal in
                if startImmediately { mbl_mw_logging_start(board, overwriting ? 1 : 0) }
                start?()
            })
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, obtain the logger's signal, returning a pointer to the logger signal. Combine interface for `mbl_mw_datasignal_log` and `mbl_mw_logger_generate_identifier`.
    ///
    func generateIdentifiableLoggerSignal() -> AnyPublisher<_AnonymousLogger, MWError> {

        let subject = PassthroughSubject<_AnonymousLogger, MWError>()
        mbl_mw_datasignal_log(self, bridge(obj: subject)) { (context, logger) in
            let _subject: PassthroughSubject<_AnonymousLogger, MWError> = bridge(ptr: context!)
            if let logger = logger {
                let cString = mbl_mw_logger_generate_identifier(logger)!
                let identifier = String(cString: cString)
                _subject.send((identifier, logger))
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not create logger")))
            }
        }
        return subject.eraseToAnyPublisher()
    }
}
