// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine


// MARK: - Battery Life

/// Battery life percentage 0 to 100
public struct MWBatteryLevel: MWDataConvertible, MWReadable {
    public typealias DataType = Int
    public typealias RawDataType = MblMwBatteryState
    public let columnHeadings = ["Epoch", "Battery Percentage"]
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_settings_get_battery_state_data_signal(board)
    }
}

extension MWReadable where Self == MWBatteryLevel {
    /// Battery life percentage 0 to 100
    public static var batteryLevel: Self { Self() }
}


// MARK: - Charging State

/// Battery's current charging state
public struct MWChargingStatus: MWDataConvertible, MWStreamable, MWLoggable {
    public typealias DataType = MWChargingStatus.State
    public typealias RawDataType = UInt32
    public var signalName: MWNamedSignal = .chargingStatus
    public let columnHeadings = ["Epoch", "Battery"]
}

extension MWStreamable where Self == MWChargingStatus {
    /// Battery's current charging state
    public static var chargingStatus: Self { Self() }
}

extension MWLoggable where Self == MWChargingStatus {
    /// Battery's current charging state
    public static var chargingStatus: Self { Self() }
}

public extension MWChargingStatus {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_settings_get_charge_status_data_signal(board)
    }

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(value: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, datum.value.label]
    }

    func streamConfigure(board: MWBoard) {}
    func streamStart(board: MWBoard) {}
    func streamCleanup(board: MWBoard) {}
}

public extension MWChargingStatus {

    /// Battery charging state
    enum State: String, CaseIterable, IdentifiableByRawValue {
        case charging
        case notCharging
        /// Feature not supported
        case unknown

        public init(value: UInt32) {
            switch value {
                case 0: self = .notCharging
                case 1: self = .charging
                default: self = .unknown
            }
        }

        public var label: String { self.rawValue.localizedCapitalized }
    }
}
