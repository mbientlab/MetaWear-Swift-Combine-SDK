// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

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
            .zip(shared.loggerSignalsCollectAll())
            .flatMap { metawear, loggers -> MWPublisher<Download<[MWData.LogDownload]>> in

                // Stop logging + subscribe/store the downloaded feed from each signal
                let downloads = loggers.reduce(into: [MWNamedSignal:CurrentValueSubject<[MWData], MWError>]()) { dict, logger in
                    logger.id.downloadUtilities.stopModule(metawear.board)
                    dict[logger.id] = _anonymous_datasignal_subscribe_accumulate(logger.log)
                }
                mbl_mw_logging_stop(metawear.board)
                mbl_mw_logging_flush_page(metawear.board)

                // Download
                var (handler, percentComplete) = _trackDownloadProgress()
                mbl_mw_logging_download(metawear.board, 50, &handler)

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
            .zip(shared.loggerSignalsCollectAll())
            .tryMap { metawear, logs -> (MetaWear, OpaquePointer) in
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

// MARK: - Collect Loggers & Clear Loggers

public extension Publisher where Output == MetaWear {

    /// Collects references to active loggers on the MetaWear.
    ///
    func loggerSignalsCollectAll() -> MWPublisher<[(id: MWNamedSignal, log: OpaquePointer)]> {
        mapToMWError()
            .flatMap { device -> MWPublisher<[(id: MWNamedSignal, log: OpaquePointer)]> in
                return device.board
                    .collectAnonymousLoggerSignals()
                    .map { log in log.map { (MWNamedSignal(identifier: $0), $1) } }
                    .erase(subscribeOn: device.bleQueue)
            }
            .eraseToAnyPublisher()
    }


    /// Deactivates the specific loggers, but does not remove logged data or power down the sensors involved in logging.
    ///
    func loggersRemoveAll(_ loggers: [OpaquePointer]) -> MWPublisher<MetaWear> {
        handleOutputOnBleQueue { metawear in
            loggers.forEach(mbl_mw_logger_remove)
        }
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
