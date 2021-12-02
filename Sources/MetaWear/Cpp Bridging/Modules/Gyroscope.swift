// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWGyroscope: MWStreamable, MWLoggable {

    public typealias DataType = SIMD3<Float>
    public typealias RawDataType = MblMwCartesianFloat
    public let loggerName: MWLogger = .gyroscope

    public var range: GraphRange? = nil
    public var frequency: Frequency? = nil
    public var needsConfiguration: Bool { range != nil || frequency != nil }

    public init(range: GraphRange? = nil, frequency: Frequency? = nil) {
        self.range = range
        self.frequency = frequency
    }
}

public extension MWGyroscope {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard let model = Model(board: board) else { return nil }
        switch model {
            case .bmi160: return mbl_mw_gyro_bmi160_get_rotation_data_signal(board)
            case .bmi270: return mbl_mw_gyro_bmi270_get_rotation_data_signal(board)
        }
    }

    func streamConfigure(board: MWBoard) {
        guard needsConfiguration else { return }
        guard let model = Model(board: board) else { return }

        switch model {
            case .bmi160:
                if let range = range {
                    mbl_mw_gyro_bmi160_set_range(board, range.cppEnumValue)
                }
                if let frequency = frequency {
                    mbl_mw_gyro_bmi160_set_odr(board, frequency.cppEnumValue)
                }
                mbl_mw_gyro_bmi160_write_config(board)

            case .bmi270:
                if let range = range {
                    mbl_mw_gyro_bmi270_set_range(board, range.cppEnumValue)
                }
                if let frequency = frequency {
                    mbl_mw_gyro_bmi270_set_odr(board, frequency.cppEnumValue)
                }
                mbl_mw_gyro_bmi270_write_config(board)
        }
    }

    func streamStart(board: MWBoard) {
        guard let model = Model(board: board) else { return }
        switch model {
            case .bmi160:
                mbl_mw_gyro_bmi160_enable_rotation_sampling(board)
                mbl_mw_gyro_bmi160_start(board)
            case .bmi270:
                mbl_mw_gyro_bmi270_enable_rotation_sampling(board)
                mbl_mw_gyro_bmi270_start(board)
        }

    }

    func streamCleanup(board: MWBoard) {
        guard let model = Model(board: board) else { return }
        switch model {
            case .bmi160:
                mbl_mw_gyro_bmi160_stop(board)
                mbl_mw_gyro_bmi160_disable_rotation_sampling(board)
            case .bmi270:
                mbl_mw_gyro_bmi270_stop(board)
                mbl_mw_gyro_bmi270_disable_rotation_sampling(board)
        }
    }

    func loggerCleanup(board: MWBoard) {
        guard let model = Model(board: board) else { return }
        switch model {
            case .bmi160:
                mbl_mw_gyro_bmi160_stop(board)
                mbl_mw_gyro_bmi160_disable_rotation_sampling(board)
            case .bmi270:
                mbl_mw_gyro_bmi270_stop(board)
                mbl_mw_gyro_bmi270_disable_rotation_sampling(board)
                mbl_mw_logging_flush_page(board)
        }
    }
}

// MARK: - Discoverable Presets

public extension MWStreamable where Self == MWGyroscope {
    static func gyroscope(range: MWGyroscope.GraphRange? = nil, freq: MWGyroscope.Frequency? = nil) -> Self {
        Self(range: range, frequency: freq)
    }
}

public extension MWLoggable where Self == MWGyroscope {
    static func gyroscope(range: MWGyroscope.GraphRange? = nil, freq: MWGyroscope.Frequency? = nil) -> Self {
        Self(range: range, frequency: freq)
    }
}

// MARK: - C++ Constants

public extension MWGyroscope {

    enum GraphRange: Int, CaseIterable, IdentifiableByRawValue {
        case dps125  = 125
        case dps250  = 250
        case dps500  = 500
        case dps1000 = 1000
        case dps2000 = 2000

        public var fullScale: Int {
            switch self {
                case .dps125: return 1
                case .dps250: return 2
                case .dps500: return 4
                case .dps1000: return 8
                case .dps2000: return 16
            }
        }

        /// Raw Cpp constant
        public var cppEnumValue: MblMwGyroBoschRange {
            switch self {
                case .dps125:  return MBL_MW_GYRO_BOSCH_RANGE_125dps
                case .dps250:  return MBL_MW_GYRO_BOSCH_RANGE_250dps
                case .dps500:  return MBL_MW_GYRO_BOSCH_RANGE_500dps
                case .dps1000: return MBL_MW_GYRO_BOSCH_RANGE_1000dps
                case .dps2000: return MBL_MW_GYRO_BOSCH_RANGE_2000dps
            }
        }
    }

    enum Frequency: Int, CaseIterable, IdentifiableByRawValue {
        case hz1600 = 1600
        case hz800  = 800
        case hz400  = 400
        case hs200  = 200
        case hz100  = 100
        case hz50   = 50
        case hz25   = 25

        /// Raw Cpp constant
        public var cppEnumValue: MblMwGyroBoschOdr {
            switch self {
                case .hz1600: return MBL_MW_GYRO_BOSCH_ODR_1600Hz
                case .hz800:  return MBL_MW_GYRO_BOSCH_ODR_800Hz
                case .hz400:  return MBL_MW_GYRO_BOSCH_ODR_400Hz
                case .hs200:  return MBL_MW_GYRO_BOSCH_ODR_200Hz
                case .hz100:  return MBL_MW_GYRO_BOSCH_ODR_100Hz
                case .hz50:   return MBL_MW_GYRO_BOSCH_ODR_50Hz
                case .hz25:   return MBL_MW_GYRO_BOSCH_ODR_25Hz
            }
        }
    }

    enum Model: String, CaseIterable, IdentifiableByRawValue {
        case bmi270
        case bmi160

        /// Raw Cpp constant
        public var int8Value: UInt8 {
            switch self {
                case .bmi270: return MBL_MW_MODULE_GYRO_TYPE_BMI270
                case .bmi160: return MBL_MW_MODULE_GYRO_TYPE_BMI160
            }
        }

        /// Cpp constant for Swift
        public var int32Value: Int32 { Int32(int8Value) }

        public init?(value: Int32) {
            switch value {
                case Self.bmi270.int32Value: self = .bmi270
                case Self.bmi160.int32Value: self = .bmi160
                default: return nil
            }
        }

        public init?(board: OpaquePointer?) {
            let accelerometer = mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_GYRO)
            self.init(value: accelerometer)
        }
    }

}
