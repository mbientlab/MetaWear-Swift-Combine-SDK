// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

/// Celcius
public struct MWThermometer: MWReadable, MWPollable {

    /// Celcius
    public typealias DataType = Float
    public typealias RawDataType = Float
    public let columnHeadings = ["Epoch", "Temperature (C)"]
    public let type: Source
    public var pollingRate: MWFrequency
    public let loggerName: MWLogger = .temperature

    public var channel: Int
    /// For external thermistors only. 0 - 5
    public var dataPin: UInt8 = 0
    /// For external thermistors only. 0 - 5
    public var pulldownPin: UInt8 = 0

    public init(type: Source, channel: Int, board: MWBoard, rate: MWFrequency = .init(eventsPerSecond: 1)) throws {
        guard Source(board: board, atChannel: channel) == type else {
            throw MWError.operationFailed("\(type.displayName) unavailable at the specified channel.")
        }
        self.type = type
        self.channel = channel
        self.pollingRate = rate
    }

    public init(type: Source, board: MWBoard, rate: MWFrequency = .init(eventsPerSecond: 1)) throws {
        let available = MWThermometer.Source.availableChannels(on: board)
        guard let i = available.firstIndex(of: type) else {
            throw MWError.operationFailed("\(type.displayName) is not available.")
        }
        self.type = type
        self.channel = i
        self.pollingRate = rate
    }
}

public extension MWThermometer {

    func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        return mbl_mw_multi_chnl_temp_get_temperature_data_signal(board, UInt8(channel))
    }

    func readConfigure(board: MWBoard) {
        if type == .external {
            mbl_mw_multi_chnl_temp_configure_ext_thermistor(board, UInt8(channel), dataPin, pulldownPin, UInt8(1))
        }
        if type == .bmp280 {
            mbl_mw_baro_bosch_start(board)
        }
    }

    func readCleanup(board: MWBoard) {
        if type == .bmp280 {
            mbl_mw_baro_bosch_stop(board)
        }
    }
}

// MARK: - Discoverable Presets

public extension MWReadable where Self == MWThermometer {

    static func thermometer(type: MWThermometer.Source = .onboard, board: MWBoard) throws -> Self {
        let available = MWThermometer.Source.availableChannels(on: board)
        guard let i = available.firstIndex(of: type) else {
            throw MWError.operationFailed("\(type.displayName) is not available.")
        }
        return try Self(type: type, channel: i, board: board, rate: .init(eventsPerSecond: 1))
    }
}

public extension MWPollable where Self == MWThermometer {

    static func thermometer(type: MWThermometer.Source = .onboard, board: MWBoard, rate: MWFrequency) throws -> Self {
        let available = MWThermometer.Source.availableChannels(on: board)
        guard let i = available.firstIndex(of: type) else {
            throw MWError.operationFailed("\(type.displayName) is not available.")
        }
        return try Self(type: type, channel: i, board: board, rate: rate)
    }
}


// MARK: - C++ Constants

public extension MWThermometer {

    enum Source: String, CaseIterable, IdentifiableByRawValue {
        case onDie
        case external
        case bmp280
        case onboard
        case custom

        public static func availableChannels(on board: MWBoard) -> [Source] {
            var channels = [Source]()
            let maxChannels = mbl_mw_multi_chnl_temp_get_num_channels(board)
            for i in 0..<maxChannels {
                channels.append(Self.init(board: board, atChannel: Int(i)))
            }
            return channels
        }

        public init(board: MWBoard, atChannel: Int) {
            let source = mbl_mw_multi_chnl_temp_get_source(board, UInt8(atChannel))
            self.init(cpp: source)
        }

        public init(cpp: MblMwTemperatureSource) {
            self = Self.allCases.first(where: { $0.cppValue == cpp }) ?? .custom
        }

        public var cppValue: MblMwTemperatureSource? {
            switch self {
                case .onDie: return MBL_MW_TEMPERATURE_SOURCE_NRF_DIE
                case .external: return MBL_MW_TEMPERATURE_SOURCE_EXT_THERM
                case .bmp280: return MBL_MW_TEMPERATURE_SOURCE_BMP280
                case .onboard: return MBL_MW_TEMPERATURE_SOURCE_PRESET_THERM
                case .custom: return nil
            }
        }

        public var displayName: String {
            switch self {
                case .onDie: return "On-Die"
                case .external: return "External"
                case .bmp280: return "BMP280"
                case .onboard: return "Onboard"
                case .custom: return "Custom"
            }
        }
    }
}
