// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp

// These contracts interact with
// MetaWear modules with type safety and
// code completion.

// You won't use the protocol's methods,
// most likely. Just know the types,
// which define a broad behavior, like
// "readable once" or "loggable".

// Each module differs in capabilities,
// customizations, and the C++ methods
// required to operate them. Some also
// have multiple models with different
// capabilities. Objects implementing
// these protocols abstract that away
// from end users — and provide a
// reference when you need to write
// your own abstractions.


// MARK: - Log

/// This module supports logging data to
/// onboard storage.
public protocol MWLoggable: MWDataConvertible {

    /// The MetaWear device's identifier
    /// for the logger.
    var loggerName: MWLogger { get }
    /// Obtains a reference to the
    /// module's loggable signal.
    func loggerDataSignal(board: MWBoard) throws -> MWDataSignal?
    /// Commands to customize the logger
    func loggerConfigure(board: MWBoard)
    /// Commands to start the signal to be logged
    func loggerStart(board: MWBoard)
    /// Commands to end the logger
    func loggerCleanup(board: MWBoard)
}

// MARK: - Stream

/// This module supports streaming data
/// at up to 100 Hz.
public protocol MWStreamable: MWDataConvertible {

    /// Obtains a reference to the module's
    /// streamable signal.
    func streamSignal(board: MWBoard) throws -> MWDataSignal?
    // Commands to customize the stream
    func streamConfigure(board: MWBoard)
    // Commands before starting the stream
    func streamStart(board: MWBoard)
    // Commands to end the stream
    func streamCleanup(board: MWBoard)
}

/// This module's data can be "streamed"
/// by polling at a reasonable interval.
public protocol MWPollable: MWReadable {

    /// The MetaWear device's identifier
    /// for the logger.
    var loggerName: MWLogger { get }

    /// Queries per second or by millisecond periods
    var pollingRate: MWFrequency { get }

    // Commands to customize the "stream"
    func pollConfigure(board: MWBoard)

    /// Obtains a reference to the module's
    /// "streamable" signal.
    func pollSensorSignal(board: MWBoard) throws -> MWDataSignal?

    func pollCleanup(board: MWBoard)
}

/// Specify event frequencies in Hz or millisecond periods between events
///
public struct MWFrequency {

    // Events per second (Hz)
    public let rateHz: Double
    // Milliseconds between events
    public let periodMs: Int

    public init(eventsPerSecond: Double) {
        self.rateHz = eventsPerSecond
        self.periodMs = Int(1/rateHz * 1000)
    }

    public init(periodMs: Int) {
        self.periodMs = periodMs
        self.rateHz = 1000 / Double(periodMs)
    }
}

// MARK: - Read Once

/// For signals that can only be read once
public protocol MWReadable: MWDataConvertible {
    func readableSignal(board: MWBoard) throws -> MWDataSignal?

    func readConfigure(board: MWBoard)

    func readCleanup(board: MWBoard)
}

// MARK: - Command

public protocol MWCommand {

    func command(board: MWBoard)
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

