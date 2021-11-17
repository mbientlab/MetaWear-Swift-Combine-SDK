////Copyright

import Foundation
import Combine

/// A type-erased publisher that subscribes and returns on its parent's BLE queue. For UI updates, add `.receive(on: DispatchQueue.main)`.
///
public typealias MetaPublisher<Output> = AnyPublisher<Output, MetaWearError>


// MARK: - Any Failure Type

public extension Publisher where Output == MetaWear {

    /// Collects references to active loggers on the MetaWear.
    ///
    func collectAnonymousLoggerSignals() -> MetaPublisher<[OpaquePointer]> {

        mapToMetaWearError()
        .flatMap { device -> MetaPublisher<[OpaquePointer]> in
            return device.board
                .collectAnonymousLoggerSignals()
                .erase(subscribeOn: device.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Creates a timer on the MetaWear.
    ///
    func createTimer(period: UInt32,
                     repetitions: UInt16 = 0xFFFF,
                     immediateFire: Bool = false
    ) -> MetaPublisher<OpaquePointer> {

        mapToMetaWearError()
        .flatMap { device -> MetaPublisher<OpaquePointer> in
            return device.board
                .createTimer(period: period, repetitions: repetitions, immediateFire: immediateFire)
                .erase(subscribeOn: device.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Ends macro recordings.
    ///
    func macroEndRecording() -> MetaPublisher<Int32> {
        mapToMetaWearError()
        .flatMap { device -> MetaPublisher<Int32> in
            return device.board
                .macroEndRecording()
                .erase(subscribeOn: device.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }
}


public extension Publisher where Output == MetaWear, Failure == MetaWearError {

    // MARK: - Stream

    /// Stream time-stamped data from the MetaWear board using a type-safe preset (with optional configuration).
    ///
    /// - Parameters:
    ///   - signal: Type-safe, configurable preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<T>(_ signal: MWSignal<T, MWLoggableStreamable>) -> MetaPublisher<Timestamped<T>> {

        flatMap { metawear -> MetaPublisher<Timestamped<T>> in
            tryMap { metaWear -> MWDataSignal in
                guard let pointer = try signal.from(metaWear.board) else {
                    throw MetaWearError.operationFailed("Board unavailable for \(signal.name).")
                }
                return pointer
            }
            .stream(as: T.self,
                    configure: { signal.configure(metawear.board) },
                    start: { signal.signalStart(metawear.board) },
                    onTerminate: { signal.streamCleanup(metawear.board) }
            )
            .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Requires some knowledge of the C++ library and unsafe Swift. Convenience publisher for a streaming board signal.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_acc_bosch_get_acceleration_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///   - configure: Block called to configure a stream (optional) before `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_set_odr`; `mbl_mw_acc_bosch_write_acceleration_config`)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `        mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<T>(signal: OpaquePointer,
                   as type: T.Type,
                   configure: EscapingHandler,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> MetaPublisher<Timestamped<T>> {

        flatMap { metawear -> MetaPublisher<Timestamped<T>> in
            signal
                .stream(as: type, configure: configure, start: start, onTerminate: onTerminate)
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }


    // MARK: - Read Once

    /// Performs a one-time read of a board signal, handling C++ library calls, pointer bridging, and returned data type casting.
    ///
    /// - Parameters:
    ///   - signal: Type-safe preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func readOnce<T>(signal: MWSignal<T, MWReadableOnce>) -> MetaPublisher<T> {
        flatMap { metawear -> MetaPublisher<T> in
            do {
                guard let signalPointer = try signal.from(metawear.board)
                else { throw MetaWearError.operationFailed("Board unavailable for \(signal.name).") }

                return signalPointer
                    .readOnce(as: T.self)
                    .mapError { _ in // Replace any unspecific type casting failure message
                        MetaWearError.operationFailed("Failed reading \(signal.name).")
                    }
                    .erase(subscribeOn: metawear.apiAccessQueue)

            } catch {
                return Fail(outputType: T.self, failure: error).mapToMetaWearError()
            }
        }
        .eraseToAnyPublisher()
    }

    /// Performs a one-time read of a board signal, handling pointer bridging, and casting to the provided type.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_settings_get_battery_state_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func readOnce<T>(signal: OpaquePointer, as type: T.Type) -> MetaPublisher<T> {
        flatMap { metawear in
            metawear.board
                .readOnce(as: T.self)
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

}

// MARK: - Public - General Operators

public extension Publisher {

    /// Sugar to ensure operations upstream of this are performed async on the provided queue.
    ///
    func erase(subscribeOn queue: DispatchQueue) -> AnyPublisher<Self.Output,Self.Failure> {
        self.subscribe(on: queue).eraseToAnyPublisher()
    }
}

public extension Publisher where Failure == MetaWearError {

    /// Sugar to erase a MetaWearError publisher to an Error publisher
    ///
    func eraseErrorType() -> AnyPublisher<Output,Error> {
        mapError({ $0 as Error }).eraseToAnyPublisher()
    }

}
