// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Battery Life

public struct MWBatteryLevel: MWDataConvertible, MWReadable {
    public typealias DataType = Int8
    public typealias RawDataType = Int8
    public let columnHeadings = ["Epoch", "Battery Percentage"]
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_settings_get_battery_state_data_signal(board)
    }
    public func readConfigure(board: MWBoard) { }
    public func readCleanup(board: MWBoard) { }
}

extension MWReadable where Self == MWBatteryLevel {
    static var batteryLevel: Self { Self() }
}


// MARK: - MAC Address

public struct MWMACAddress: MWDataConvertible, MWReadable {
    public typealias DataType = String
    public typealias RawDataType = String
    public let columnHeadings = ["Epoch", "MAC"]
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_settings_get_mac_data_signal(board)
    }
    public func readConfigure(board: MWBoard) { }
    public func readCleanup(board: MWBoard) { }
}

extension MWReadable where Self == MWMACAddress {
    static var macAddress: Self { Self() }
}

// MARK: - Log Length

/// Bytes
public struct MWLogLength: MWDataConvertible, MWReadable {
    public typealias DataType = Int
    public typealias RawDataType = UInt32
    public let columnHeadings = ["Epoch", "Logs (Bytes)"]
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_logging_get_length_data_signal(board)
    }
    public func readConfigure(board: MWBoard) { }
    public func readCleanup(board: MWBoard) { }
}

extension MWReadable where Self == MWLogLength {
    static var logLength: Self { Self() }
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
    public func readConfigure(board: MWBoard) { }
    public func readCleanup(board: MWBoard) { }

    public func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, (Date(timeIntervalSinceReferenceDate: Double(raw.value.epoch) / 1000), raw.value.reset_uid) )
    }

    public func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, String(datum.value.time.timeIntervalSinceReferenceDate)]
    }
}

extension MWReadable where Self == MWLastResetTime {
    static var lastResetTime: Self { Self() }
}
