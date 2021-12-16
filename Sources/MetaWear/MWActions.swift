// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp

// These contracts interact with
// MetaWear modules with type safety and
// code completion.
//
// You can ignore the protocol's contents,
// but do know the log, stream, read, and
// command action types, as these are how
// to interact with MetaWears.
//
// Each module differs in capabilities,
// customizations, and the C++ methods
// required to operate them. Some also
// have multiple sensor models with different
// capabilities. Objects implementing
// these protocols abstract that away
// from you — and provide a
// reference when you need to write
// your own abstractions.


// MARK: - Log

/// Sensors that can log data to onboard storage adhere to this protocol
/// to configure, start, stop, and download the logger.
///
/// To start logging, use the `.log()` operators. These are
/// available on a `Publisher` whose output is a `MetaWear`, including:
/// - ``MetaWear/MetaWear/publish()``
/// - ``MetaWear/MetaWear/publishIfConnected()``
/// - ``MetaWear/MetaWear/publishWhenConnected()``
///
/// These operators accept `MWLoggable` instances construct by
/// autocompletion, such as ``MWLoggable/sensorFusionQuaternion(mode:)``,
/// or by direct construction, such as `MWSensorFusion` ``MWSensorFusion/Quaternion/init(mode:)``.
///
/// ```swift
/// metawear
///    .publishWhenConnected()
///    .first()
///    .mapToMWError() // Changes Failure from Never to MWError
///    .log(.sensorFusionQuaternion(mode: .ndof)
///    .log(.gyroscope(range: .dps2000, frequency: .hz400)
///    .sink { _ in }
///    .store(in: &subs)
/// ```
///
/// Direct construction may be useful when you persist user selected settings
/// or organize arbitrarily large logging sessions. The SDK includes the operators
/// `.macro(executeOnBoot:)` and `.optionallyLog` to help with this.
///
/// ```swift
/// let pressure = MWBarometer.MWPressure(standby: .ms125, iir: .off, oversampling: .standard)
/// let gyro = MWGyroscope(range: .dps1000, frequency: .hz400)
/// let euler: MWSensorFusion.EulerAngles? = nil
///
/// metawear
///     .publishIfConnected()
///     .macro(executeOnBoot: true) { metawear in
///          metawear
///             .optionallyLog(euler)
///             .optionallyLog(gyro)
///             .optionallyLog(pressure)
///     }
///     .sink { _ in }
///     .store(in: &subs)
/// ```
///
/// Our open-source **MetaBase 5** app provides a similar example in [ActionVM.swift](https://github.com/mbientlab/MetaBase/blob/6bc70d01be561565de2755c85c810d784ef68760/Shared/Screens/4_Action/VMs/ActionVM.swift#L224) and [MetaWear+WriteSensorMacro.swift](https://github.com/mbientlab/MetaBase/blob/6bc70d01be561565de2755c85c810d784ef68760/Shared/Screens/4_Action/VMs/MetaWear+WriteSensorMacro.swift)
/// by creating a macro of multiple `MWLoggable` and `MWPollable` signals
/// from arbitrary user-selected sensors and sensor parameters.
///
/// Downloading logs in CSV format is simple with the `.downloadLogs` operator,
/// also demonstrated in the aforementioned MetaBase app.
///
/// Unless you construct your own sensor wrappers, this protocol's details
/// and default methods are unlikely to be important to you.
///
public protocol MWLoggable: MWDataConvertible {

    /// Obtains a reference to the module's loggable signal.
    func loggerDataSignal(board: MWBoard) throws -> MWDataSignal?
    /// Commands to customize the logger.
    func loggerConfigure(board: MWBoard)
    /// Commands to start the data signal.
    func loggerStart(board: MWBoard)
    /// Commands after unsubscribing from the logger signal.
    func loggerCleanup(board: MWBoard)
    /// Identifier for downloadable logger signal when exporting an ``MWDataTable``.
    var signalName: MWNamedSignal { get }
}

// MARK: - Stream

/// Sensors that can stream data at about 100 to 120 Hz
/// adhere to this protocol to configure, start, and stop a
/// data signal.
///
/// To start a stream, use the `.stream()` operators. They are available
/// on a `Publisher` whose output is a `MetaWear`, including:
/// - ``MetaWear/MetaWear/publish()``
/// - ``MetaWear/MetaWear/publishIfConnected()``
/// - ``MetaWear/MetaWear/publishWhenConnected()``
///
/// A `.stream()` operator accepts an `MWStreamable` instance.
/// You can use presets that autocomplete within the operator,
/// such as ``MWStreamable/magnetometer(freq:)``, or construct
/// them directly, such as ``MWMagnetometer/init(freq:)``.
///
/// Some `.stream()` operators produce a timestamped typed output.
/// You can collect these into an array and convert that into a
/// String-only CSV table with aptly labeled columns by using
/// ``MWDataTable``, such as in the example below.
///
/// ```swift
/// let cancel = PassthroughSubject<Void,Never>()
/// let config: MWStreamable = .magnetometer(freq: .hz25)
/// metawear
///     .publishIfConnected()
///     .stream(config)
///     .prefix(untilOutputFrom: cancel)
///     .collect()
///     .map { MWDataTable(streamed: $0, config) }
///     .eraseToAnyPublisher()
/// ```
///
/// Multiple `.stream` pipelines can run independently. You
/// can also merge the output of an arbitrary array of streams
/// using standard operators like `MergeMany`, `.prefix(untilOutputFrom:)`,
/// and `.collect()` . Our open-source **MetaBase 5** app provides an
/// example in [ActionVM.swift](https://github.com/mbientlab/MetaBase/blob/6bc70d01be561565de2755c85c810d784ef68760/Shared/Screens/4_Action/VMs/ActionVM.swift#L276). It uses user-selected (and persisted) sensor parameters
/// to inform the construction a container of `MWStreamable` configurations.
/// Only non-nil configs are streamed. Upon cancellation, outputs merge
/// into a single CSV file. The hyperlinked function is called as
/// part of a loop across an arbitrary number of devices.
///
/// Unless you construct your own sensor wrappers, this protocol's details
/// and default methods are unlikely to be important to you.
///
public protocol MWStreamable: MWDataConvertible {

    /// Commands to customize the stream.
    func streamConfigure(board: MWBoard)
    /// Obtains a reference to the module's already-configured streamable signal.
    func streamSignal(board: MWBoard) throws -> MWDataSignal?
    /// Commands before starting the stream.
    func streamStart(board: MWBoard)
    /// Called after unsubscribing from the data signal.
    func streamCleanup(board: MWBoard)
    /// Identifier for signal when exporting an ``MWDataTable``.
    var signalName: MWNamedSignal { get }
}

/// Sensors natively incapable of continuous output, such as thermistors,
/// can output "streamable" and loggable outputs with the help of
/// onboard timers that fire at reasonable intervals. This protocol
/// organizes the methods and properties for polling such sensors.
///
/// To start polling, use the `.stream()` or `.log()` operators. These are
/// available on a `Publisher` whose output is a `MetaWear`, including:
/// - ``MetaWear/MetaWear/publish()``
/// - ``MetaWear/MetaWear/publishIfConnected()``
/// - ``MetaWear/MetaWear/publishWhenConnected()``
///
/// These operators accept `MWPollable` instances constructed by
/// autocompletion, such as ``MWPollable/humidity(oversampling:rate:)``,
/// or directly, such as ``MWHumidity/init(oversampling:rate:)``.
///
/// Direct construction may be useful for patterns where you persist
/// user selected settings or organize arbitrarily large logging or
/// streaming sessions. Our open-source **MetaBase 5** app provides an example
/// in [ActionVM.swift](https://github.com/mbientlab/MetaBase/blob/6bc70d01be561565de2755c85c810d784ef68760/Shared/Screens/4_Action/VMs/ActionVM.swift#L224) of starting logging and streaming sessions with arbitrary
/// mixes of `MWPollable`, `MWStreamable`, and `MWLoggable` sensors with merged
/// outputs.
///
/// Unless you construct your own sensor wrappers, this protocol's details
/// are unlikely to be important to you.
///
public protocol MWPollable: MWReadable {

    /// Obtains a reference to the module's "streamable" signal.
    func pollSensorSignal(board: MWBoard) throws -> MWDataSignal?
    /// Commands to customize the "stream"
    func pollConfigure(board: MWBoard)
    /// Called after unsubscribing to the event signal.
    func pollCleanup(board: MWBoard)
    /// Identifier for downloadable signal when exporting an ``MWDataTable``.
    var signalName: MWNamedSignal { get }
    /// Rate at which an event fires to read the sensor's signal.
    var pollingRate: MWFrequency { get }

}

// MARK: - Read Once

/// For signals that can only be read once

/// Sensors natively incapable of continuous output, such as thermistors,
/// adopt this protocol to organize configuring, reading, and closing a
/// sensor's data signal.
///
/// To read the sensor, use the `.read()` operator. It is available on a
/// `Publisher` whose output is a `MetaWear`, including:
/// - ``MetaWear/MetaWear/publish()``
/// - ``MetaWear/MetaWear/publishIfConnected()``
/// - ``MetaWear/MetaWear/publishWhenConnected()``
///
/// These operators accept `MWReadable` instances constructed by
/// autocompletion, such as ``MWReadable/thermometer(type:board:)``,
/// or directly, such as ``MWThermometer/init(type:channel:rate:)``.
///
/// ```swift
/// metawear
///    .publishIfConnected()
///    .read(.humidity(oversampling: .x1))
/// ```
///
/// Unless you construct your own sensor wrappers, this protocol's details
/// are unlikely to be important to you.
///
public protocol MWReadable: MWDataConvertible {

    /// Obtains are reference to the readable data signal.
    func readableSignal(board: MWBoard) throws -> MWDataSignal?
    /// Commands to configure the sensor before reading.
    func readConfigure(board: MWBoard)
    /// Called after unsubscribing to the read signal.
    func readCleanup(board: MWBoard)
}

/// A read command that coalesces multiple operations into one output.
///
public protocol MWReadableExtended {
    associatedtype DataType
    /// Obtains are reference to the readable data signal.
    func read(from device: MetaWear) -> MWPublisher<DataType>
}

// MARK: - Command

/// Issues a command to the MetaWear, such as recording a macro
/// or resetting to factory defaults.
///
public protocol MWCommand {
    func command(board: MWBoard)
}

/// A command that returns a value.
///
public protocol MWCommandOutcome {
    associatedtype DataType
    /// Obtains are reference to the readable data signal.
    func command(device: MetaWear) -> MWPublisher<(result: DataType, metawear: MetaWear)>
}

// MARK: - Internal Defaults (DRY)

public extension MWLoggable where Self: MWStreamable {

    func loggerDataSignal(board: MWBoard) throws -> MWDataSignal? {
        try self.streamSignal(board: board)
    }

    func loggerConfigure(board: MWBoard) {
        self.streamConfigure(board: board)
    }

    func loggerStart(board: MWBoard) {
        self.streamStart(board: board)
    }

    func loggerCleanup(board: MWBoard) {
        self.streamCleanup(board: board)
    }
}

public extension MWPollable {

    func pollConfigure(board: MWBoard) {
        self.readConfigure(board: board)
    }

    func pollSensorSignal(board: MWBoard) throws -> MWDataSignal? {
        try self.readableSignal(board: board)
    }

    func pollCleanup(board: MWBoard) {
        self.readCleanup(board: board)
    }
}

public extension MWReadable {
    func readConfigure(board: MWBoard) { }
    func readCleanup(board: MWBoard) { }
}
