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
    public let signalName: MWNamedSignal

    public var channel: Int
    /// For external thermistors only. 0 - 5
    public var dataPin: UInt8 = 0
    /// For external thermistors only. 0 - 5
    public var pulldownPin: UInt8 = 0

    /// Verifies channel and source alignment before streaming or logging.
    ///
    public init(rate: MWFrequency = .init(hz: 1), type: Source, channel: Int, board: MWBoard) throws {
        guard Source(board: board, atChannel: channel) == type else {
            throw MWError.operationFailed("\(type.displayName) unavailable at the specified channel.")
        }
        self.type = type
        self.channel = channel
        self.pollingRate = rate
        self.signalName = .temperature
    }

    /// Verifies channel and source alignment before streaming or logging.
    ///
    public init(rate: MWFrequency = .init(hz: 1), type: Source, board: MWBoard) throws {
        let available = MWThermometer.Source.availableChannels(on: board)
        guard let i = available.firstIndex(of: type) else {
            throw MWError.operationFailed("\(type.displayName) is not available.")
        }
        self.type = type
        self.channel = i
        self.pollingRate = rate
        self.signalName = .temperature
    }

    /// Does not verify that the source is at the specified channel,
    /// exposing possible faults when attempting to log or stream.
    /// Useful when using the Metadata package and channels are known.
    ///
    public init(rate: MWFrequency, type: Source, channel: Int) {
        self.type = type
        self.channel = channel
        self.pollingRate = rate
        self.signalName = .temperature
    }
}

public extension MWThermometer {

    func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        return mbl_mw_multi_chnl_temp_get_temperature_data_signal(board, UInt8(channel))
    }

    func readConfigure(board: MWBoard) {
        if type == .external {
            mbl_mw_multi_chnl_temp_configure_ext_thermistor(board, UInt8(channel), dataPin, pulldownPin, UInt8(1))
        } else if type == .bmp280 {
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

    /// Thermistor reports degrees Celsius.
    ///
    static func thermometer(type: MWThermometer.Source = .onboard, board: MWBoard) throws -> Self {
        let available = MWThermometer.Source.availableChannels(on: board)
        guard let i = available.firstIndex(of: type) else {
            throw MWError.operationFailed("\(type.displayName) is not available.")
        }
        return try Self(rate: .init(hz: 1), type: type, channel: i, board: board)
    }
}

public extension MWPollable where Self == MWThermometer {

    /// Thermistor reports degrees Celsius.
    ///
    static func thermometer(rate: MWFrequency, type: MWThermometer.Source = .onboard, board: MWBoard) throws -> Self {
        let available = MWThermometer.Source.availableChannels(on: board)
        guard let i = available.firstIndex(of: type) else {
            throw MWError.operationFailed("\(type.displayName) is not available.")
        }
        return try Self(rate: rate,  type: type, channel: i, board: board)
    }
}


// MARK: - C++ Constants

public extension MWThermometer {

    /// - Warning: Do not depend on `Codable` conformance for persistence.
    ///            Use for in-memory drag and drop only.
    ///
    enum Source: String, CaseIterable, IdentifiableByRawValue, Codable {
        case onDie
        case onboard
        case external
        case bmp280
        case custom

        /// Thermometer sources. Indexes correspond to channel number.
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

        public var loggerIndex: String {
            switch self {
                case .onDie: return "[0]"
                case .external: return "[2]"
                case .bmp280: return "[3]"
                case .onboard: return "[1]"
                case .custom: return "[]"
            }
        }
    }
}
