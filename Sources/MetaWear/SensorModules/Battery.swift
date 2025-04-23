// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

// MARK: - Battery Life

extension MWReadable where Self == MWBatteryLevel {
    /// Battery life percentage 0 to 100
    public static var batteryLevel: Self { Self() }
}


/// Battery life percentage 0 to 100
public struct MWBatteryLevel: MWDataConvertible, MWReadable {
    public typealias DataType = Int
    public typealias RawDataType = Int // Check its ok
    
    public let columnHeadings = ["Epoch", "Battery Percentage"]
    
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        //mbl_mw_settings_get_battery_state_data_signal(board)
        // TO DO
        let switchResponseHeader = ResponseHeader(moduleID: Module.button.byte, registerID: READ_REGISTER(Module.button.rawValue))
        let dataSignal = MWDataSignal(header: switchResponseHeader, owner: board, interpreter: DataInterpreter.INT32)
        board.moduleEvents[switchResponseHeader] = dataSignal
        return dataSignal
    }
}

// MARK: - Charging State

extension MWStreamable where Self == MWChargingStatus {
    /// Battery's current charging state
    public static var chargingStatus: Self { Self() }
}

extension MWLoggable where Self == MWChargingStatus {
    /// Battery's current charging state
    public static var chargingStatus: Self { Self() }
}


/// Battery's current charging state
public struct MWChargingStatus: MWDataConvertible, MWStreamable, MWLoggable {
    public typealias DataType = MWChargingStatus.State
    public typealias RawDataType = UInt32
    public var signalName: MWNamedSignal = .chargingStatus
    public let columnHeadings = ["Epoch", "Battery"]
}

public extension MWChargingStatus {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        //mbl_mw_settings_get_charge_status_data_signal(board)
        // TO DO
        let switchResponseHeader = ResponseHeader(moduleID: Module.button.byte, registerID: READ_REGISTER(Module.button.rawValue))
        let dataSignal = MWDataSignal(header: switchResponseHeader, owner: board, interpreter: DataInterpreter.INT32)
        board.moduleEvents[switchResponseHeader] = dataSignal
        return dataSignal
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
