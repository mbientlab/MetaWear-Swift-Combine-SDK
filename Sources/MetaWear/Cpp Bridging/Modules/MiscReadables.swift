// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Log Length

/// Bytes
public struct MWLogLength: MWDataConvertible, MWReadable {
    public typealias DataType = Int
    public typealias RawDataType = UInt32
    public let columnHeadings = ["Epoch", "Logs (Bytes)"]
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_logging_get_length_data_signal(board)
    }
}

extension MWReadable where Self == MWLogLength {
    public static var logLength: Self { Self() }
}


// MARK: - Reset Time

/// Board Restart Time
public struct MWLastResetTime: MWDataConvertible, MWReadable {
    public typealias DataType = (time: Date, resetID: UInt8)
    public typealias RawDataType = MblMwLoggingTime
    public let columnHeadings = ["Epoch", "Time"]
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_logging_get_time_data_signal(board)
    }
}

extension MWReadable where Self == MWLastResetTime {
    public static var lastResetTime: Self { Self() }
}


// MARK: - MAC Address

/// After connection or if remembered, a MetaWear's ``MetaWear/MetaWear/info`` property exposes the stable MAC address.
public struct MWMACAddress: MWDataConvertible, MWReadable {
    public typealias DataType = String
    public typealias RawDataType = String
    public let columnHeadings = ["Epoch", "MAC"]
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_settings_get_mac_data_signal(board)
    }
}

extension MWReadable where Self == MWMACAddress {
    /// After connection or if remembered, a MetaWear's ``MetaWear/MetaWear/info`` property exposes the stable MAC address.
    public static var macAddress: Self { Self() }
}
