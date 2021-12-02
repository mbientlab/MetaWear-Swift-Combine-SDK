// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWMagnetometer: MWStreamable, MWLoggable {

    public typealias DataType = SIMD3<Float>
    public typealias RawDataType = MblMwCartesianFloat
    public let loggerName: MWLogger = .magnetometer

    public var frequency: SampleFrequency? = nil

    public init(frequency: MWMagnetometer.SampleFrequency? = nil) {
        self.frequency = frequency
    }
}

public extension MWMagnetometer {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_mag_bmm150_get_b_field_data_signal(board)
    }

    func streamConfigure(board: MWBoard) {
        if let frequency = frequency {
            mbl_mw_mag_bmm150_configure(board, 9, 15, frequency.cppValue)
        }
    }

    func streamStart(board: MWBoard) {
        mbl_mw_mag_bmm150_enable_b_field_sampling(board)
        mbl_mw_mag_bmm150_start(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_mag_bmm150_stop(board)
        mbl_mw_mag_bmm150_disable_b_field_sampling(board)
    }

    func loggerCleanup(board: MWBoard) {
        streamCleanup(board: board)
    }
}


// MARK: - Discoverable Presets

public extension MWStreamable where Self == MWMagnetometer {
    static func magnetometer(freq: MWMagnetometer.SampleFrequency? = nil) -> Self {
        Self(frequency: freq)
    }
}

public extension MWLoggable where Self == MWMagnetometer {
    static func magnetometer(freq: MWMagnetometer.SampleFrequency? = nil) -> Self {
        Self(frequency: freq)
    }
}


// MARK: - C++ Constants

extension MWMagnetometer {


    /// Hertz. BIMM150 magnetometer.
    public enum SampleFrequency: Int, CaseIterable, IdentifiableByRawValue {
        case hz30 = 30
        case hz25 = 25
        case hz20 = 20
        case hz15 = 15
        case hz10 = 10
        case hz8  = 8
        case hz6  = 6
        case hz2  = 2

        public var cppValue: MblMwMagBmm150Odr {
            switch self {
                case .hz30: return MBL_MW_MAG_BMM150_ODR_30Hz
                case .hz25: return MBL_MW_MAG_BMM150_ODR_25Hz
                case .hz20: return MBL_MW_MAG_BMM150_ODR_20Hz
                case .hz15: return MBL_MW_MAG_BMM150_ODR_15Hz
                case .hz10: return MBL_MW_MAG_BMM150_ODR_10Hz
                case .hz8:  return MBL_MW_MAG_BMM150_ODR_8Hz
                case .hz6:  return MBL_MW_MAG_BMM150_ODR_6Hz
                case .hz2:  return MBL_MW_MAG_BMM150_ODR_2Hz
            }
        }
    }
}
