////Copyright

import Foundation
import MetaWearCpp
import Combine

public typealias Timestamped<T> = (timestamp: Date, value: T)
public typealias EscapingHandler = (() -> Void)?
public typealias MWDataSignal = OpaquePointer

public extension Publisher where Output == MWDataSignal {
    /// - Parameters:
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///   - configure: Block called to configure a stream (optional) before `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_set_odr`; `mbl_mw_acc_bosch_write_acceleration_config`)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `        mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    func stream<T>(as: T.Type,
                   configure: EscapingHandler,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> AnyPublisher<Timestamped<T>, MetaWearError> {
        
        mapToMetaWearError()
            .flatMap { dataSignal -> AnyPublisher<Timestamped<T>, MetaWearError> in
                dataSignal
                    .stream(as: T.self,
                            configure: configure,
                            start: start,
                            onTerminate: onTerminate)
            }
            .eraseToAnyPublisher()
    }

    /// When receiving a data signal, starts logging the signal. Combine interface for `mbl_mw_datasignal_log`.
    ///
    func logger() -> AnyPublisher<OpaquePointer, MetaWearError> {
        mapToMetaWearError()
        .flatMap { signal -> AnyPublisher<OpaquePointer, MetaWearError> in
            signal.logger()
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Utilities on an `MWDataSignal` `OpaquePointer`

// MARK: - Stream Signal

public extension MWDataSignal {

    /// When pointing to a data signal, start streaming the signal. Performs:
    /// `mbl_mw_datasignal_subscribe`
    ///  On cancel: `mbl_mw_datasignal_unsubscribe`
    ///
    /// - Parameters:
    ///   - configure: Block called to configure a stream (optional) before `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_set_odr`; `mbl_mw_acc_bosch_write_acceleration_config`)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `        mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    func stream<T>(as: T.Type,
                   configure: EscapingHandler,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> AnyPublisher<Timestamped<T>, MetaWearError> {

        stream(configure: configure, start: start, onTerminate: onTerminate)
            .mapError { _ in // Replace a generic stream error
                MetaWearError.operationFailed("Could not stream \(T.self)")
            }
            .map { ($0.timestamp, $0.valueAs() as T) }
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, start streaming the signal. Performs:
    /// `.copy()`
    /// `mbl_mw_datasignal_subscribe`
    ///  On cancel: `mbl_mw_datasignal_unsubscribe`
    ///
    /// - Parameters:
    ///   - configure: Block called to configure a stream (optional) before `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_set_odr`; `mbl_mw_acc_bosch_write_acceleration_config`)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `        mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    func stream(configure: EscapingHandler,
                start: EscapingHandler,
                onTerminate: EscapingHandler
    ) -> AnyPublisher<MetaWearData, MetaWearError> {

        let subject = PassthroughSubject<MetaWearData, MetaWearError>()

        configure?()

        mbl_mw_datasignal_subscribe(self, bridgeRetained(obj: subject)) { (context, dataPtr) in
            let _subject: PassthroughSubject<MetaWearData, MetaWearError> = bridgeTransfer(ptr: context!)

            if let dataPtr = dataPtr {
                _subject.send(dataPtr.pointee.copy())
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not subscribe")))
            }
        }

        start?()

        return subject
            .handleEvents(receiveCompletion: { completion in
                onTerminate?()
                mbl_mw_datasignal_unsubscribe(self)
            }, receiveCancel: {
                onTerminate?()
                mbl_mw_datasignal_unsubscribe(self)
            })
            .eraseToAnyPublisher()
    }
}

// MARK: - Logger Signal

public extension MWDataSignal {

    /// When pointing to a data signal, start logging the signal, returning a pointer to the logger. Combine interface for `mbl_mw_datasignal_log`
    ///
    func logger() -> AnyPublisher<OpaquePointer, MetaWearError> {

        let subject = PassthroughSubject<OpaquePointer, MetaWearError>()
        mbl_mw_datasignal_log(self, bridgeRetained(obj: subject)) { (context, logger) in
            let _subject: PassthroughSubject<OpaquePointer,MetaWearError> = bridgeTransfer(ptr: context!)

            if let logger = logger {
                _subject.send(logger)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create log entry")))
            }
        }
        return subject.eraseToAnyPublisher()
    }
}

// MARK: - Read (Log) Signal

public extension MWDataSignal {

    /// Combine interface for a one-time read of a MetaWear data signal. Performs:
    /// `mbl_mw_datasignal_subscribe`
    /// `dataPtr.pointee.copy`
    /// `.valueAs`
    /// `mbl_mw_datasignal_read`
    /// `mbl_mw_datasignal_unsubscribe`  (on cancel or completion)
    ///
    func readOnce<T>(as: T.Type) -> AnyPublisher<T, MetaWearError> {
        readOnce()
            .mapError { _ in // Replace a generic readOnce error
                MetaWearError.operationFailed("Could not read \(T.self)")
            }
            .map { $0.valueAs() as T }
            .eraseToAnyPublisher()
    }

    /// Combine interface for a one-time read of a MetaWear data signal. Performs:
    /// `mbl_mw_datasignal_subscribe`
    /// `dataPtr.pointee.copy`
    /// `.valueAs`
    /// `mbl_mw_datasignal_read`
    /// `mbl_mw_datasignal_unsubscribe` (on cancel or completion)
    ///
    func readOnceTimestamped<T>(as: T.Type) -> AnyPublisher<Timestamped<T>, MetaWearError> {
        readOnce()
            .mapError { _ in // Replace a generic readOnce error
                MetaWearError.operationFailed("Could not read \(T.self)")
            }
            .map { ($0.timestamp, $0.valueAs() as T) }
            .eraseToAnyPublisher()
    }

    /// Combine interface for a one-time read of a MetaWear data signal. Performs:
    /// `mbl_mw_datasignal_subscribe`
    /// `dataPtr.pointee.copy` ->  timestamped raw`MetaWearData`
    /// `mbl_mw_datasignal_read`
    /// `mbl_mw_datasignal_unsubscribe` (on cancel or completion)
    ///
    func readOnce() -> AnyPublisher<MetaWearData, MetaWearError> {
        assert(mbl_mw_datasignal_is_readable(self) != 0)
        let subject = PassthroughSubject<MetaWearData, MetaWearError>()

        mbl_mw_datasignal_subscribe(self, bridgeRetained(obj: subject)) { (context, dataPtr) in
            let _subject: PassthroughSubject<MetaWearData, MetaWearError> = bridgeTransfer(ptr: context!)

            if let dataPtr = dataPtr {
                _subject.send(dataPtr.pointee.copy())
                _subject.send(completion: .finished)
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not subscribe")))
            }
        }

        mbl_mw_datasignal_read(self)

        return subject
            .handleEvents(receiveCompletion: { completion in
                mbl_mw_datasignal_unsubscribe(self)
            }, receiveCancel: {
                mbl_mw_datasignal_unsubscribe(self)
            })
            .eraseToAnyPublisher()
    }

}
