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
public typealias MWLoggerSignal           = OpaquePointer

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
