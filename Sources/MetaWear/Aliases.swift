// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Combine Aliases

/// This publisher subscribes and returns on
/// its parent scanner's Bluetooth queue to
/// ensure safe usage of the MetaWear C++ library.
///
/// To update your UI, use
/// `.receive(on: DispatchQueue.main)`.
///
public typealias MWPublisher<Output>  = AnyPublisher<Output, MWError>


// MARK: - Signal Aliases

/// References the MetaWear's board
public typealias MWBoard                = OpaquePointer

/// References a signal from a board
/// module (e.g., accelerometer) for
/// streaming, logging, or reading
/// `MblMwDataSignal`
public typealias MWDataSignal           = OpaquePointer

/// References a board or data signal
/// (e.g., for a data processor)
public typealias MWDataSignalOrBoard    = OpaquePointer

/// References a data processor output,
/// which can be read or fed back into
/// other data processors
public typealias MWDataProcessorSignal  = OpaquePointer

/// References a signal referring to a
/// logger for a particular data signal
public typealias MWLoggerSignal         = OpaquePointer

/// References a timer signal
public typealias MWTimerSignal          = OpaquePointer

// MARK: - Other Aliases

public typealias Timestamped<V>         = (time: Date, value: V)

/// Recorded macro identifier
public typealias MWMacroIdentifier = UInt8

/// Tuple of the approximate percentage
///  of data already downloaded
///  (by page size, not actual entries)
///  and, once 100% complete, the
///  downloaded data itself.
public typealias Download<D>             = (data: D, percentComplete: Double)

/// A 6-byte unique identifier for a MetaWear and any Bluetooth device (e.g., F1:4A:45:90:AC:9D)
public typealias MACAddress              = String

/// While stable locally, Apple identifies CoreBluetooth peripherals via a UUID that differs between a user's phones and computers. Once connected, a MetaWear's `MetaWear/MetaWear/info`` property exposes the stable MAC address, as does our advertising packet when seen via Android.
public typealias CBPeripheralIdentifier  = UUID

public extension CBPeripheralIdentifier {
     typealias UUIDString                = String
}
