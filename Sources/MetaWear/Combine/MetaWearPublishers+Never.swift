////Copyright

import Foundation
import Combine

// MARK: - Public API For Failure Type == Never
// (These alias Failure == MetaWearError operators)

public extension Publisher where Output == MetaWear, Failure == Never {

    /// Performs a one-time read of a board signal, handling C++ library calls, pointer bridging, and returned data type casting.
    ///
    /// - Parameters:
    ///   - signal: Type-safe preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func readOnce<T>(signal: MWSignal<T, MWReadableOnce>) -> MetaPublisher<T> {
        setFailureType(to: MetaWearError.self)
            .readOnce(signal: signal)
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
        setFailureType(to: MetaWearError.self)
            .readOnce(signal: signal, as: type.self)
    }

    /// Stream time-stamped data from the MetaWear board using a type-safe preset (with optional configuration).
    ///
    /// - Parameters:
    ///   - signal: Type-safe, configurable preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<T>(_ signal: MWSignal<T, MWLoggableStreamable>) -> MetaPublisher<Timestamped<T>> {
        setFailureType(to: MetaWearError.self)
            .stream(signal)
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
        setFailureType(to: MetaWearError.self)
            .stream(signal: signal, as: type, configure: configure, start: start, onTerminate: onTerminate)
    }
}

