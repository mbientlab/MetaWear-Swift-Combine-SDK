// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Start Logging

public extension Publisher where Output == MetaWear {

    /// Starts logging a preset sensor configuration.
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func log<L: MWLoggable>(_ loggable: L, overwriting: Bool = false) -> MWPublisher<MetaWear> {
        let errorMsg = MWError.operationFailed("Unable to log \(loggable.name)")
        return self
            .handleEvents(receiveOutput: { loggable.loggerConfigure(board: $0.board) })
            .tryMap { mw -> (MetaWear, OpaquePointer) in
                guard let signal = try loggable.loggerDataSignal(board: mw.board)
                else { throw errorMsg }
                return (mw, signal)
            }
            .mapToMetaWearError()
            .flatMap { metawear, signal -> MWPublisher<MetaWear> in
                signal
                    .log(board: metawear.board,
                         overwriting: overwriting,
                         start: { loggable.loggerStart(board: metawear.board) }
                    )
                    .compactMap { [weak metawear] _ in metawear }
                    .mapError { _ in errorMsg }
                    .erase(subscribeOn: metawear.apiAccessQueue)
            }
            .share()
            .eraseToAnyPublisher()
    }

    #warning("Handle custom loggable signal names by adding them to the cache")

    /// Starts logging a preset sensor configuration that works by polling a readable signal.
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func log<P: MWPollable>(byPolling pollable: P, overwriting: Bool = false) -> MWPublisher<MetaWear> {
        tryMap { metawear -> (metawear: MetaWear, sensor: MWDataSignal) in
            guard let moduleSignal = try pollable.pollSensorSignal(board: metawear.board)
            else { throw MWError.operationFailed("Could not create \(pollable.name)") }
            pollable.pollConfigure(board: metawear.board)
            return (metawear, moduleSignal)
        }
        .mapToMetaWearError()
        .flatMap { o -> MWPublisher<MetaWear> in
            log(byPolling: o.sensor, rate: pollable.pollingRate, overwriting: overwriting)
                .mapError { _ in MWError.operationFailed("Unable to log \(pollable.name)") }
                .erase(subscribeOn: o.metawear.apiAccessQueue)
        }
        .share()
        .eraseToAnyPublisher()
    }
    /// Starts logging any data signal that can be read by `mbl_mw_datasignal_read` at the intervals specified.
    /// - Returns: The connected MetaWear or an error if the logging attempt fails.
    ///
    func log(byPolling readableSignal: MWDataSignal, rate: MWFrequency, overwriting: Bool = false) -> MWPublisher<MetaWear> {
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
            .flatMap { o -> MWPublisher<MetaWear> in
                let device = o.metawear
                return o.countedSensor
                    .makeLoggerSignal()
                    .handleEvents(receiveOutput: { [weak device] _ in
                        guard let device = device else { return }
                        mbl_mw_logging_start(device.board, overwriting ? 1 : 0)
                        mbl_mw_timer_start(o.timer)
                    })
                    .compactMap { [weak device] _ in device }
                    .subscribe(on: device.apiAccessQueue)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

}

// MARK: - Download Logs

public extension Publisher where Output == MetaWear, Failure == MWError {

    /// Downloads all logs into a `String` format that can convert into a .csv file.
    /// You can also get an `MWData` array output using `_logDownloadData()`.
    /// - Returns: Publishes percent complete. At 100% complete, publishes all logged data.
    ///
    func logsDownload() -> MWPublisher<Download<[MWDataTable]>> {
        _logDownloadData()
            .map { ($0.map(MWDataTable.init), $1) }
            .eraseToAnyPublisher()
    }

    /// Downloads all logs in the raw `MWData` format.
    /// - Returns: Publishes percent complete. At 100% complete, publishes all logged data.
    ///
    func _logDownloadData() -> MWPublisher<Download<[MWData.LogDownload]>> {

        zip(collectAnonymousLoggerSignals())
            .flatMap { metawear, loggers -> MWPublisher<Download<[MWData.LogDownload]>> in

                // Stop logging + subscribe/store the downloaded feed from each signal
                let downloads = loggers.reduce(into: [MWLogger:CurrentValueSubject<[MWData], MWError>]()) { dict, logger in
                    logger.id.downloadUtilities.stopModule(metawear.board)
                    dict[logger.id] = _datasignal_subscribe_accumulate(logger.log)
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
                        refs: (device: MetaWear, logs: [(id: MWLogger, log: OpaquePointer)] ),
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
                    .erase(subscribeOn: metawear.apiAccessQueue)
            }
            .eraseToAnyPublisher()
    }

    /// Downloads only the specific logger signal that you specify, ignoring all others.
    /// - Returns: Publishes percent complete. At 100% complete, publishes all logged data.
    ///
    func logDownload<L: MWLoggable>(_ loggable: L)
    -> MWPublisher<Download<[Timestamped<L.DataType>]>> {

        zip(collectAnonymousLoggerSignals())
            .tryMap { metawear, logs -> (MetaWear, OpaquePointer) in
                guard let logger = logs.first(where: { $0.id == loggable.loggerName }) else {
                    throw MWError.operationFailed("Could not find logger \(loggable.name)")
                }
                return (metawear, logger.log)
            }
            .mapToMetaWearError()
            .download(loggable)
            .eraseToAnyPublisher()
    }
}

// MARK: - Collect Loggers & Clear Loggers

public extension Publisher where Output == MetaWear, Failure == MWError {

    /// Collects references to active loggers on the MetaWear.
    ///
    func collectAnonymousLoggerSignals() -> MWPublisher<[(id: MWLogger, log: OpaquePointer)]> {

        flatMap { device -> MWPublisher<[(id: MWLogger, log: OpaquePointer)]> in
            return device.board
                .collectAnonymousLoggerSignals()
                .map { log in log.map { (MWLogger(identifier: $0), $1) } }
                .erase(subscribeOn: device.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Wipes logged data.
    ///
    func deleteLoggedEntries() -> MWPublisher<MetaWear> {
        flatMap { metawear in
            _JustMW(metawear)
                .handleEvents(receiveOutput: { metaWear in
                    mbl_mw_logging_clear_entries(metaWear.board)
                })
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }
}


// MARK: - Download Logs (One Signal Only)

public extension Publisher where Output == (MetaWear, MWLoggerSignal), Failure == MWError {

    /// Download one logger signal, ignoring all others.
    /// - Parameters:
    ///   - metawear: Connected MetaWear
    ///   - loggerCleanup: Closure to perform to stop the signal being logged
    /// - Returns: Publishes percentage complete, with an empty array of data until 100% (1.0) downloaded
    ///
    func download<L: MWLoggable>(_ loggable: L)
    -> MWPublisher<Download<MWDataTable>> {

        download(loggable.loggerName, loggerCleanup: loggable.loggerCleanup)
            .map { data, percentage -> Download<MWDataTable> in
                (.init(download: data), percentage)
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

        download(loggable.loggerName, loggerCleanup: loggable.loggerCleanup)
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
    func download(_ loggerName: MWLogger,
                  loggerCleanup: @escaping (MWBoard) -> Void
    ) -> MWPublisher<Download<MWData.LogDownload>> {

        flatMap { metawear, logger -> MWPublisher<Download<MWData.LogDownload>> in
            // Stop recording
            loggerCleanup(metawear.board)
            mbl_mw_logging_stop(metawear.board)
            mbl_mw_logging_flush_page(metawear.board)

            // Download
            let data = _datasignal_subscribe_accumulate(logger)
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
                .erase(subscribeOn: metawear.apiAccessQueue)
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
             start:     (() -> Void)?
    ) -> AnyPublisher<(id: MWLogger, signal: OpaquePointer), MWError> {

        mapToMetaWearError()
            .flatMap { signal -> AnyPublisher<(id: MWLogger, signal: OpaquePointer), MWError> in
                signal.log(board: board, overwriting: overwriting, start: start)
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
             start:       (() -> Void)?
    ) -> AnyPublisher<(id: MWLogger, signal: OpaquePointer), MWError> {

        makeLoggerSignal()
            .map { (MWLogger(identifier: $0), $1) }
            .handleEvents(receiveOutput: { id, signal in
                let resetID = mbl_mw_logging_get_latest_reset_uid(board)
                let epoch = Int64(Date().timeIntervalSinceReferenceDate * 1000)
                #warning("Had expected this to change the reset time for this ID.")
                mbl_mw_logging_set_reference_time(board, resetID, epoch)
                mbl_mw_logging_start(board, overwriting ? 1 : 0)
                start?()
            })
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, obtain the logger's signal, returning a pointer to the logger signal. Combine interface for `mbl_mw_datasignal_log` and `mbl_mw_logger_generate_identifier`.
    ///
    func makeLoggerSignal() -> AnyPublisher<_AnonymousLogger, MWError> {

        let subject = PassthroughSubject<_AnonymousLogger, MWError>()
        mbl_mw_datasignal_log(self, bridge(obj: subject)) { (context, logger) in
            let _subject: PassthroughSubject<_AnonymousLogger, MWError> = bridge(ptr: context!)
            if let logger = logger {
                let cString = mbl_mw_logger_generate_identifier(logger)!
                let identifier = String(cString: cString)
//                mbl_mw_memory_free(UnsafeMutableRawPointer(mutating: cString)) pointer being freed was not allocated
                #warning("Memory")
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
                let signal = signals[Int(i)]!
                let id = mbl_mw_anonymous_datasignal_get_identifier(signal)!
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
