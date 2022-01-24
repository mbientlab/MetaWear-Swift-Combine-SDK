// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Start Logging

public extension Publisher where Output == MetaWear {

    /// Starts recording data from all loggers currently setup.
    ///
    /// - Parameters:
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///
    /// - Returns: The connected MetaWear.
    ///
    func startCurrentLoggers(overwriting: Bool = false) -> MWPublisher<MetaWear> {
        handleOutputOnBleQueue { mw in
            mbl_mw_logging_start(mw.board, overwriting ? 1 : 0)
        }
    }

    /// Stops recording data from all loggers, but doesn't cancel them and keeps sensors active.
    ///
    /// - Parameters:
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///
    /// - Returns: The connected MetaWear.
    ///
    func pauseCurrentLoggers(overwriting: Bool = false) -> MWPublisher<MetaWear> {
        handleOutputOnBleQueue { mw in
            mbl_mw_logging_stop(mw.board)
        }
    }

    /// Logs a preset sensor configuration.
    ///
    /// - Parameters:
    ///   - loggable: Instance of a sensor configuration that supports logging its signal to onboard storage
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///   - startsImmediately: Start logging immediately upon issuing this command
    ///
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func log<L: MWLoggable>(
        _ loggable: L,
        overwriting: Bool = false,
        startImmediately: Bool = true
    ) -> MWPublisher<MetaWear> {

        let errorMsg = MWError.operationFailed("Unable to log \(loggable.name)")
        return self
            .handleEvents(receiveOutput: { loggable.loggerConfigure(board: $0.board) })
            .tryMap { mw -> (MetaWear, OpaquePointer) in
                guard let signal = try loggable.loggerDataSignal(board: mw.board)
                else { throw errorMsg }
                return (mw, signal)
            }
            .mapToMWError()
            .flatMap { metawear, signal -> MWPublisher<MetaWear> in
                signal
                    .log(board: metawear.board,
                         overwriting: overwriting,
                         startImmediately: startImmediately,
                         start: { loggable.loggerStart(board: metawear.board) }
                    )
                    .compactMap { [weak metawear] _ in metawear }
                    .replaceMWError(errorMsg)
                    .erase(subscribeOn: metawear.bleQueue)
            }
            .share()
            .eraseToAnyPublisher()
    }

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
                    .makeLoggerSignal()
                    .compactMap { [weak metawear] _ in metawear }
                    .eraseToAnyPublisher()
            }
            .flatMap { metawear -> MWPublisher<MetaWear> in
                metawear.board
                    .createTimedEvent(
                        period: UInt32(rate.periodMs),
                        repetitions: .max,
                        immediateFire: false,
                        recordedEvent: { Swift.print("-> mbl_mw_datasignal_read", #function); mbl_mw_datasignal_read(signal) }
                    )
                    .handleEvents(receiveOutput: { timer in
                        Swift.print("-> mbl_mw_logging_start", #function)
                        if startsImmediately { mbl_mw_logging_start(metawear.board, overwriting ? 1 : 0) }
                        Swift.print("-> mbl_mw_timer_start", #function)
                        mbl_mw_timer_start(timer)
                    })
                    .compactMap { [weak metawear] _ in metawear }
                    .erase(subscribeOn: metawear.bleQueue)
            }
            .eraseToAnyPublisher()
    }

    /// Given a non-nil preset, starts logging a preset sensor configuration.
    ///
    /// - Parameters:
    ///   - loggable: Instance of a sensor configuration that supports logging its signal to onboard storage
    ///   - overwriting: When flash memory is full, continue logging by overwriting data
    ///   - startsImmediately: Start logging immediately upon issuing this command
    ///
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func optionallyLog<L: MWLoggable>(
        _ loggable: L?,
        overwriting: Bool = false,
        startsImmediately: Bool = true
    ) -> MWPublisher<MetaWear> {

        if let loggable = loggable {
            return self.log(loggable, overwriting: overwriting, startImmediately: startsImmediately)
        } else { return self.mapToMWError() }
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

// MARK: - Download Logs

public extension Publisher where Output == MetaWear {

    /// Downloads all logs into a `String` format that can convert into a .csv file.
    /// You can also get an `MWData` array output using `_logDownloadData()`.
    ///
    /// - Parameter startDate: A timestamp you have cached for when the logging session started. Used to calculate elapsed time in an output CSV files, potentially synchronized across multiple devices. (A MetaWear ticks time, but lacks a calendar-aware clock.)
    ///
    /// - Returns: Publishes percent complete. At 100% complete, publishes all logged data.
    ///
    func downloadLogs(startDate: Date) -> MWPublisher<Download<[MWDataTable]>> {
        _logDownloadData()
            .map { ($0.map { MWDataTable(download: $0, startDate: startDate) }, $1) }
            .eraseToAnyPublisher()
    }

    /// Downloads all logs in the raw `MWData` format.
    /// - Returns: Publishes percent complete. At 100% complete, publishes all logged data.
    ///
    func _logDownloadData() -> MWPublisher<Download<[MWData.LogDownload]>> {
        let shared = self.mapToMWError().share()
        return shared
            .zip(shared.collectAnonymousLoggerSignals())
            .flatMap { metawear, loggers -> MWPublisher<Download<[MWData.LogDownload]>> in

                Swift.print("-> \(loggers.map(\.id.id))", #function)

                // Stop logging + subscribe/store the downloaded feed from each signal
                let downloads = loggers.reduce(into: [MWNamedSignal:CurrentValueSubject<[MWData], MWError>]()) { dict, logger in
                    logger.id.downloadUtilities.stopModule(metawear.board)
                    dict[logger.id] = _anonymous_datasignal_subscribe_accumulate(logger.log)
                }
                mbl_mw_logging_stop(metawear.board)
                mbl_mw_logging_flush_page(metawear.board)

                // Download
                var (handler, percentComplete) = _trackDownloadProgress()
                mbl_mw_logging_download(metawear.board, 25, &handler)

                // Extend OpaquePointer lifetime
                return Publishers.CombineLatest(_JustMW((metawear, loggers)), percentComplete)
                // Only pass data when 100% downloaded
                    .eraseToAnyPublisher()
                    .map({ (refs, download) -> (
                        refs: (device: MetaWear, logs: [(id: MWNamedSignal, log: OpaquePointer)] ),
                        download: Download<[MWData.LogDownload]>
                    ) in
                        let data = download.percentComplete == 1 ? downloads.latest() : []
                        return (refs, (data, download.percentComplete))
                    })
                    .handleEvents(receiveOutput: { output in
                        guard output.download.percentComplete == 1
                                && output.download.data.contains(where: { !$0.data.isEmpty })
                        else { return }
                        output.refs.logs.forEach { mbl_mw_logger_remove($0.log) }
                        mbl_mw_logging_clear_entries(output.refs.device.board)
                    })
                    .map(\.download)
                    .erase(subscribeOn: metawear.bleQueue)
            }
            .eraseToAnyPublisher()
    }

    /// Downloads only the specific logger signal that you specify, ignoring all others.
    /// - Returns: Publishes percent complete. At 100% complete, publishes all logged data.
    ///
    func downloadLog<L: MWLoggable>(_ loggable: L)
    -> MWPublisher<Download<[Timestamped<L.DataType>]>> {
        let shared = self.mapToMWError().share()
        return shared
            .zip(shared.collectAnonymousLoggerSignals())
            .tryMap { metawear, logs -> (MetaWear, OpaquePointer) in
                Swift.print("-> \(logs.map(\.id.id))", #function)
                guard let logger = logs.first(where: { $0.id == loggable.signalName }) else {
                    throw MWError.operationFailed("Could not find logger \(loggable.name)")
                }
                return (metawear, logger.log)
            }
            .mapToMWError()
            .download(loggable)
            .eraseToAnyPublisher()
    }
}

// MARK: - Collect Loggers & Clear Loggers

public extension Publisher where Output == MetaWear {

    /// Collects references to active loggers on the MetaWear.
    ///
    func collectAnonymousLoggerSignals() -> MWPublisher<[(id: MWNamedSignal, log: OpaquePointer)]> {
        mapToMWError()
            .flatMap { device -> MWPublisher<[(id: MWNamedSignal, log: OpaquePointer)]> in
                return device.board
                    .collectAnonymousLoggerSignals()
                    .map { log in log.map { (MWNamedSignal(identifier: $0), $1) } }
                    .erase(subscribeOn: device.bleQueue)
            }
            .eraseToAnyPublisher()
    }


    /// Deactivates the specific loggers.
    ///
    func removeLoggers(_ loggers: [OpaquePointer]) -> MWPublisher<MetaWear> {
        handleOutputOnBleQueue { metawear in
            loggers.forEach(mbl_mw_logger_remove)
        }
    }

    /// Wipes logged data.
    ///
    func deleteLoggedEntries() -> MWPublisher<MetaWear> {
        handleOutputOnBleQueue { mw in
            mbl_mw_logging_clear_entries(mw.board)
        }
    }
}


// MARK: - Download Logs (One Signal Only)

public extension Publisher where Output == (MetaWear, MWLoggerSignal) {

    /// Download one logger signal, ignoring all others.
    /// - Parameters:
    ///   - metawear: Connected MetaWear
    ///   - loggerCleanup: Closure to perform to stop the signal being logged
    /// - Returns: Publishes percentage complete, with an empty array of data until 100% (1.0) downloaded
    ///
    func download<L: MWLoggable>(_ loggable: L, startDate: Date)
    -> MWPublisher<Download<MWDataTable>> {

        download(loggable.signalName, loggerCleanup: loggable.loggerCleanup)
            .map { data, percentage -> Download<MWDataTable> in
                (.init(download: data, startDate: startDate), percentage)
            }
            .eraseToAnyPublisher()
    }

    /// Download one logger signal, ignoring all others.
    /// - Parameters:
    ///   - metawear: Connected MetaWear
    ///   - loggerCleanup: Closure to perform to stop the signal being logged
    /// - Returns: Publishes percentage complete, with an empty array of data until 100% (1.0) downloaded
    ///
    func download<L: MWLoggable>(_ loggable: L)
    -> MWPublisher<Download<[Timestamped<L.DataType>]>> {

        download(loggable.signalName, loggerCleanup: loggable.loggerCleanup)
            .map { data, percentage -> Download<[Timestamped<L.DataType>]> in
                (data.data.map(loggable.convertRawToSwift), percentage)
            }
            .eraseToAnyPublisher()
    }

    /// Download one logger signal, ignoring all others.
    /// - Parameters:
    ///   - metawear: Connected MetaWear
    ///   - loggerCleanup: Closure to perform to stop the signal being logged
    /// - Returns: Publishes percentage complete, with an empty array of data until 100% (1.0) downloaded
    ///
    func download(_ loggerName: MWNamedSignal,
                  loggerCleanup: @escaping (MWBoard) -> Void
    ) -> MWPublisher<Download<MWData.LogDownload>> {

        mapToMWError()
            .flatMap { metawear, logger -> MWPublisher<Download<MWData.LogDownload>> in
                // Stop recording
                loggerCleanup(metawear.board)
                mbl_mw_logging_stop(metawear.board)
                mbl_mw_logging_flush_page(metawear.board)

                // Download
                Swift.print("-> _anonymous_datasignal_subscribe_accumulate \(loggerName.id)", #function)
                let data = _anonymous_datasignal_subscribe_accumulate(logger)
                var (handler, percentComplete) = _trackDownloadProgress()
                mbl_mw_logging_download(metawear.board, 25, &handler)

                // Extend OpaquePointer lifetime
                return Publishers.CombineLatest(_JustMW((metawear, logger)), percentComplete)
                // Only pass data when 100% downloaded
                    .map { refs, download -> (
                        refs: (device: MetaWear, log: OpaquePointer),
                        download: Download<MWData.LogDownload>
                    ) in
                        let data = download.percentComplete == 1 ? data.value : []
                        let dataContainer = MWData.LogDownload(logger: loggerName, data: data)
                        return (refs, (dataContainer, download.percentComplete))
                    }
                // Clear logger upon completion
                    .handleEvents(receiveOutput: { output in
                        guard !output.download.data.data.isEmpty && output.download.percentComplete == 1
                        else { return }
                        mbl_mw_logger_remove(output.refs.log)
                        mbl_mw_logging_clear_entries(output.refs.device.board)
                    })
                // Pass only the download, not references
                    .map(\.download)
                // Ensure idemmnopotent
                    .share()
                    .erase(subscribeOn: metawear.bleQueue)
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - MblMwDataSignal

public extension Publisher where Output == MWDataSignal {

    /// When receiving a configured data signal, starts logging after obtaining the logger's signal, returning a pointer to the logger signal with a typed identifier. Combine interface for `mbl_mw_datasignal_log`, `mbl_mw_logger_generate_identifier`, and `mbl_mw_logging_start`.
    ///
    /// - Parameters:
    ///   - board: Pointer to the MetaWear's board
    ///   - overwriting: Whether to overwrite existing data
    ///   - start: Block to start the given data signal's sensor(s)
    /// - Returns: Logger identifier and reference
    ///
    func log(board: MWBoard,
             overwriting: Bool,
             startImmediately: Bool,
             start:     (() -> Void)?
    ) -> AnyPublisher<(id: MWNamedSignal, signal: OpaquePointer), MWError> {

        mapToMWError()
            .flatMap { signal -> AnyPublisher<(id: MWNamedSignal, signal: OpaquePointer), MWError> in
                signal.log(board: board, overwriting: overwriting, startImmediately: startImmediately, start: start)
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
    func log(board:       MWBoard,
             overwriting: Bool,
             startImmediately: Bool,
             start:       (() -> Void)?
    ) -> AnyPublisher<(id: MWNamedSignal, signal: OpaquePointer), MWError> {

        makeLoggerSignal()
            .map { (MWNamedSignal(identifier: $0), $1) }
            .handleEvents(receiveOutput: { id, signal in
                print("-> mbl_mw_logging_start", #function)
                if startImmediately { mbl_mw_logging_start(board, overwriting ? 1 : 0) }
                start?()
            })
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, obtain the logger's signal, returning a pointer to the logger signal. Combine interface for `mbl_mw_datasignal_log` and `mbl_mw_logger_generate_identifier`.
    ///
    func makeLoggerSignal() -> AnyPublisher<_AnonymousLogger, MWError> {

        let subject = PassthroughSubject<_AnonymousLogger, MWError>()
        print("-> mbl_mw_datasignal_log", #function)
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

public extension MWBoard {

    /// When pointing to a board, collects an array of logger signals, paired with an identifier, that are active on the board. Combine wrapper for `mbl_mw_metawearboard_create_anonymous_datasignals` and `mbl_mw_anonymous_datasignal_get_identifier`.
    ///
    func collectAnonymousLoggerSignals() -> PassthroughSubject<[_AnonymousLogger], MWError> {
        let subject = PassthroughSubject<[_AnonymousLogger], MWError>()

        mbl_mw_metawearboard_create_anonymous_datasignals(self, bridge(obj: subject)) { (context, board, anonymousSignals, count) in
            let _subject: PassthroughSubject<[_AnonymousLogger], MWError> = bridge(ptr: context!)

            guard let signals = anonymousSignals else {
                let status = MWStatusCode(cpp: .init(count))
                if status == .ok {
                    _subject.send([])
                    _subject.send(completion: .finished)
                    return
                } else {
                    let msg = "Could not create anonymous data signals (\(status?.rawValue ?? "unknown \(count)" ))"
                    _subject.send(completion: .failure(.operationFailed(msg)))
                    return
                }
            }

            var identified = [_AnonymousLogger]()
            for i in (0..<count) {
                guard let signal = signals[Int(i)],
                      let id = mbl_mw_anonymous_datasignal_get_identifier(signal) else {
                          NSLog("MetaWear Error: Logger Signal Unknown")
                          continue
                      }
                let idString = String(cString: id)
                identified.append((idString, signal))
            }
            _subject.send(identified)
            _subject.send(completion: .finished)
        }
        return subject
    }

}

// MARK: - Helpers
public typealias _AnonymousLogger = (id: String, log: OpaquePointer)
public typealias _DownloadProgressSubject = CurrentValueSubject<Download<[MWData]>, MWError>

public func _trackDownloadProgress() -> (handler: MblMwLogDownloadHandler, progress: _DownloadProgressSubject) {

    var handler = MblMwLogDownloadHandler()
    let percentComplete = _DownloadProgressSubject(([],0))
    handler.context = bridge(obj: percentComplete)
    handler.received_progress_update = { context, remaining, total in
        let _subject: _DownloadProgressSubject = bridge(ptr: context!)
        let percentage = Double(remaining) / Double(total)
        let percentageRemaining = percentage.isNaN ? 0 : percentage
        let percentageComplete = 1 - percentageRemaining
        _subject.send(([], percentageComplete))
        if percentageComplete == 1 {
            _subject.send(completion: .finished)
        }
    }
    return (handler, percentComplete)
}
