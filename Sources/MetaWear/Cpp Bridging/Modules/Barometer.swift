// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWBarometer { }

extension MWBarometer {

    /// Meters
    public struct MWAltitude: MWStreamable, MWLoggable {

        /// Meters
        public typealias DataType = Float
        public typealias RawDataType = Float
        public let columnHeadings = ["Epoch", "Absolute Altitude (m)"]
        public let loggerName: MWLogger = .altitude

        public var standby: StandbyTime?
        public var iir: IIRFilter?
        public var oversampling: Oversampling?
        public var needsConfiguration: Bool { standby != nil || iir != nil || oversampling != nil }

        public init(standby: MWBarometer.StandbyTime? = nil, iir: MWBarometer.IIRFilter? = nil, oversampling: MWBarometer.Oversampling? = nil) {
            self.standby = standby
            self.iir = iir
            self.oversampling = oversampling
        }
    }

    /// Pascals (Pa)
    public struct MWPressure: MWStreamable, MWLoggable {

        /// Pascals (Pa)
        public typealias DataType = Float
        public typealias RawDataType = Float
        public let columnHeadings = ["Epoch", "Pressure (Pa)"]
        public let loggerName: MWLogger = .pressure

        public var standby: StandbyTime?
        public var iir: IIRFilter?
        public var oversampling: Oversampling?
        public var needsConfiguration: Bool { standby != nil || iir != nil || oversampling != nil }

        public init(standby: MWBarometer.StandbyTime? = nil, iir: MWBarometer.IIRFilter? = nil, oversampling: MWBarometer.Oversampling? = nil) {
            self.standby = standby
            self.iir = iir
            self.oversampling = oversampling
        }
    }

}

public extension MWBarometer.MWAltitude {
    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_baro_bosch_get_altitude_data_signal(board)
    }

    func streamConfigure(board: MWBoard) {
        MWBarometer.configureBarometer(board, standby, iir, oversampling, needsConfiguration)
    }

    func streamStart(board: MWBoard) {
        mbl_mw_baro_bosch_start(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_baro_bosch_stop(board)
    }
}

public extension MWBarometer.MWPressure {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_baro_bosch_get_pressure_data_signal(board)
    }

    func streamConfigure(board: MWBoard) {
        MWBarometer.configureBarometer(board, standby, iir, oversampling, needsConfiguration)
    }

    func streamStart(board: MWBoard) {
        mbl_mw_baro_bosch_start(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_baro_bosch_stop(board)
    }
}

internal extension MWBarometer {
    static func configureBarometer(_ board: MWBoard, _ standby: StandbyTime?, _ iir: IIRFilter?, _ oversampling: Oversampling?, _ needsConfiguration: Bool) {
        guard needsConfiguration else { return }
        if let oversampling = oversampling {
            mbl_mw_baro_bosch_set_oversampling(board, oversampling.cppEnumValue)
        }
        if let iir = iir {
            mbl_mw_baro_bosch_set_iir_filter(board, iir.cppEnumValue)
        }
        if let standby = standby, let model = MWBarometer.Model(board: board) {
            switch model {
                case .bme280: mbl_mw_baro_bme280_set_standby_time(board, standby.BME_cppEnumValue)
                case .bmp280: mbl_mw_baro_bmp280_set_standby_time(board, standby.BMP_cppEnumValue)
            }
        }
        mbl_mw_baro_bosch_write_config(board)
    }
}

// MARK: - Discoverable Presets

public extension MWStreamable where Self == MWBarometer.MWAltitude {
    static func absoluteAltitude(standby: MWBarometer.StandbyTime? = nil,
                                 iir: MWBarometer.IIRFilter? = nil,
                                 oversampling: MWBarometer.Oversampling? = nil) -> Self {
        Self(standby: standby, iir: iir, oversampling: oversampling)
    }
}
public extension MWStreamable where Self == MWBarometer.MWPressure {
    static func relativePressure(standby: MWBarometer.StandbyTime? = nil,
                                 iir: MWBarometer.IIRFilter? = nil,
                                 oversampling: MWBarometer.Oversampling? = nil) -> Self {
        Self(standby: standby, iir: iir, oversampling: oversampling)
    }
}

public extension MWLoggable where Self == MWBarometer.MWAltitude {
    static func absoluteAltitude(standby: MWBarometer.StandbyTime? = nil,
                                 iir: MWBarometer.IIRFilter? = nil,
                                 oversampling: MWBarometer.Oversampling? = nil) -> Self {
        Self(standby: standby, iir: iir, oversampling: oversampling)
    }
}
public extension MWLoggable where Self == MWBarometer.MWPressure {
    static func relativePressure(standby: MWBarometer.StandbyTime? = nil,
                                 iir: MWBarometer.IIRFilter? = nil,
                                 oversampling: MWBarometer.Oversampling? = nil) -> Self {
        Self(standby: standby, iir: iir, oversampling: oversampling)
    }
}

// MARK: - C++ Constants

public extension MWBarometer {

    /// Wait between readings
    enum StandbyTime: Int, CaseIterable, IdentifiableByRawValue {
        /// 83.3 Hz
        case ms0_5
        /// Unavailable on the BMP module. 46.5 Hz
        case ms10
        /// Unavailable on the BMP module. 31.8 Hz
        case ms20
        /// 13.5 Hz
        case ms62_5
        /// 7.33 Hz
        case ms125
        /// 3.82 Hz
        case ms250
        /// 1.96 Hz
        case ms500
        /// 0.99 Hz
        case ms1000

        /// Unavailable on the BME module. 0.5 Hz
        case ms2000
        /// Unavailable on the BME module. 0.25 Hz
        case ms4000

        public static let BMPoptions: [Self] = [
            .ms0_5,
    // Missing these two options
            .ms62_5,
            .ms125,
            .ms250,
            .ms500,
            .ms1000,
            .ms2000,
            .ms4000
        ]

        public static let BMEoptions: [Self] = [
            .ms0_5,
            .ms10,
            .ms20,
            .ms62_5,
            .ms125,
            .ms250,
            .ms500,
            .ms1000
            // Missing these two options
        ]

        /// Returns an Int except for 0.5 and 62.5 ms
        public var displayName: String {
            switch self {
                case .ms0_5: return "0.5"
                case .ms62_5: return "62.5"
                default: return String(rawValue)
            }
        }

        public static func supported(by model: Model) -> [StandbyTime] {
            switch model {
                case .bme280: return Self.BMEoptions
                case .bmp280: return Self.BMPoptions
            }
        }

        public func supported(by model: Model) -> StandbyTime {
            switch model {
                case .bme280:
                    switch self {
                        case .ms2000: return .ms1000
                        case .ms4000: return .ms1000
                        default: return self
                    }

                case .bmp280:
                    switch self {
                        case .ms20:  return .ms62_5
                        case .ms10:  return .ms62_5
                        default: return self
                    }
            }
        }

        public var BME_cppEnumValue: MblMwBaroBme280StandbyTime {
            switch self {
                case .ms0_5: return MBL_MW_BARO_BME280_STANDBY_TIME_0_5ms
                case .ms10: return MBL_MW_BARO_BME280_STANDBY_TIME_10ms
                case .ms20: return MBL_MW_BARO_BME280_STANDBY_TIME_20ms
                case .ms62_5: return MBL_MW_BARO_BME280_STANDBY_TIME_62_5ms
                case .ms125: return MBL_MW_BARO_BME280_STANDBY_TIME_125ms
                case .ms250: return MBL_MW_BARO_BME280_STANDBY_TIME_250ms
                case .ms500: return MBL_MW_BARO_BME280_STANDBY_TIME_500ms
                case .ms1000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms

                case .ms2000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms // Not present
                case .ms4000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms // Not present
            }
        }

        public var BMP_cppEnumValue: MblMwBaroBmp280StandbyTime {
            switch self {
                case .ms0_5: return MBL_MW_BARO_BMP280_STANDBY_TIME_0_5ms

                case .ms62_5: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms
                case .ms125: return MBL_MW_BARO_BMP280_STANDBY_TIME_125ms
                case .ms250: return MBL_MW_BARO_BMP280_STANDBY_TIME_250ms
                case .ms500: return MBL_MW_BARO_BMP280_STANDBY_TIME_500ms
                case .ms1000: return MBL_MW_BARO_BMP280_STANDBY_TIME_1000ms
                case .ms2000: return MBL_MW_BARO_BMP280_STANDBY_TIME_2000ms
                case .ms4000: return MBL_MW_BARO_BMP280_STANDBY_TIME_4000ms

                case .ms10: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms // Not present
                case .ms20: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms // Not present
            }
        }
    }

    enum IIRFilter: Int, CaseIterable, IdentifiableByRawValue {
        case off
        case avg2
        case avg4
        case avg8
        case avg16

        public var cppEnumValue: MblMwBaroBoschIirFilter {
            switch self {
                case .off: return MBL_MW_BARO_BOSCH_IIR_FILTER_OFF
                case .avg2: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_2
                case .avg4: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_4
                case .avg8: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_8
                case .avg16: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_16
            }
        }

        public var displayName: String {
            switch self {
                case .off: return "Off"
                case .avg2: return "2"
                case .avg4: return "4"
                case .avg8: return "8"
                case .avg16: return "16"
            }
        }
    }

    enum Oversampling: Int, CaseIterable, IdentifiableByRawValue {
        case ultraLowPower
        case lowPower
        case standard
        case high
        case ultraHigh

        public var cppEnumValue: MblMwBaroBoschOversampling {
            switch self {
                case .ultraLowPower: return MBL_MW_BARO_BOSCH_OVERSAMPLING_ULTRA_LOW_POWER
                case .lowPower: return MBL_MW_BARO_BOSCH_OVERSAMPLING_LOW_POWER
                case .standard: return MBL_MW_BARO_BOSCH_OVERSAMPLING_STANDARD
                case .high: return MBL_MW_BARO_BOSCH_OVERSAMPLING_HIGH
                case .ultraHigh: return MBL_MW_BARO_BOSCH_OVERSAMPLING_ULTRA_HIGH
            }
        }

        public var displayName: String {
            switch self {
                case .ultraLowPower: return "Ultra Low"
                case .lowPower: return "Low"
                case .standard: return "Standard"
                case .high: return "High"
                case .ultraHigh: return "Ultra High"
            }
        }
    }

    enum Model: String, CaseIterable, IdentifiableByRawValue {
        case bmp280
        case bme280

        /// Raw Cpp constant
        public var int8Value: UInt8 {
            switch self {
                case .bmp280: return MetaWearCpp.MBL_MW_MODULE_BARO_TYPE_BMP280
                case .bme280: return MetaWearCpp.MBL_MW_MODULE_BARO_TYPE_BME280
            }
        }

        /// Cpp constant for Swift
        public var int32Value: Int32 { Int32(int8Value) }

        public init?(value: Int32) {
            switch value {
                case Self.bmp280.int32Value: self = .bmp280
                case Self.bme280.int32Value: self = .bme280
                default: return nil
            }
        }

        public init?(board: OpaquePointer?) {
            let device = mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_BAROMETER)
            self.init(value: device)
        }
    }

}
