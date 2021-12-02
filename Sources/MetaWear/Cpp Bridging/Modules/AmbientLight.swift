// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

/// Lux (Illuminance)
public struct MWAmbientLight: MWStreamable {

    /// Lux (Illuminance)
    public typealias DataType = Double
    public typealias RawDataType = UInt32
    public let columnHeadings = ["Epoch", "Lux"]

    public var gain: Gain? = nil
    public var integrationTime: IntegrationTime? = nil
    public var rate: MeasurementRate? = nil
    public var needsConfiguration: Bool { gain != nil || integrationTime != nil || rate != nil }

    public init(gain: MWAmbientLight.Gain? = nil, integrationTime: MWAmbientLight.IntegrationTime? = nil, rate: MWAmbientLight.MeasurementRate? = nil) {
        self.gain = gain
        self.integrationTime = integrationTime
        self.rate = rate
    }
}

public extension MWAmbientLight {

    func convert(from raw: Timestamped<UInt32>) -> Timestamped<Double> {
        (raw.time, Double(raw.value) / 1000)
    }

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_als_ltr329_get_illuminance_data_signal(board)
    }

    func streamConfigure(board: MWBoard) {
        guard needsConfiguration else { return }
        if let gain = gain { mbl_mw_als_ltr329_set_gain(board, gain.cppEnumValue) }
        if let time = integrationTime { mbl_mw_als_ltr329_set_integration_time(board, time.cppEnumValue) }
        if let rate = rate { mbl_mw_als_ltr329_set_measurement_rate(board, rate.cppEnumValue) }
        mbl_mw_als_ltr329_write_config(board)
    }

    func streamStart(board: MWBoard) {
        mbl_mw_als_ltr329_start(board)
    }

    func streamCleanup(board: MWBoard) {
        mbl_mw_als_ltr329_stop(board)
    }
}

// MARK: - Discoverable Presets

public extension MWStreamable where Self == MWAmbientLight {
    static func ambientLight(rate: MWAmbientLight.MeasurementRate? = nil,
                             gain: MWAmbientLight.Gain? = nil,
                             integrationTime: MWAmbientLight.IntegrationTime? = nil) -> Self {
        Self(gain: gain, integrationTime: integrationTime, rate: rate)
    }
}

// MARK: - C++ Constants

public extension MWAmbientLight {

    enum Gain: Int, CaseIterable, IdentifiableByRawValue {
        case gain1  = 1
        case gain2  = 2
        case gain4  = 4
        case gain8  = 8
        case gain48 = 48
        case gain96 = 96

        public var cppEnumValue: MblMwAlsLtr329Gain {
            switch self {
                case .gain1: return MBL_MW_ALS_LTR329_GAIN_1X
                case .gain2: return MBL_MW_ALS_LTR329_GAIN_2X
                case .gain4: return MBL_MW_ALS_LTR329_GAIN_4X
                case .gain8: return MBL_MW_ALS_LTR329_GAIN_8X
                case .gain48: return MBL_MW_ALS_LTR329_GAIN_48X
                case .gain96: return MBL_MW_ALS_LTR329_GAIN_96X
            }
        }
    }

    enum IntegrationTime: Int, CaseIterable, IdentifiableByRawValue {
        case ms50  = 50
        case ms100 = 100
        case ms150 = 150
        case ms200 = 200
        case ms250 = 250
        case ms300 = 300
        case ms350 = 350
        case ms400 = 400

        public var cppEnumValue: MblMwAlsLtr329IntegrationTime {
            switch self {
                case .ms50: return MBL_MW_ALS_LTR329_TIME_50ms
                case .ms100: return MBL_MW_ALS_LTR329_TIME_100ms
                case .ms150: return MBL_MW_ALS_LTR329_TIME_150ms
                case .ms200: return MBL_MW_ALS_LTR329_TIME_200ms
                case .ms250: return MBL_MW_ALS_LTR329_TIME_250ms
                case .ms300: return MBL_MW_ALS_LTR329_TIME_300ms
                case .ms350: return MBL_MW_ALS_LTR329_TIME_350ms
                case .ms400: return MBL_MW_ALS_LTR329_TIME_400ms
            }
        }
    }

    enum MeasurementRate: Int, CaseIterable, IdentifiableByRawValue {
        case ms50   = 50
        case ms100  = 100
        case ms200  = 200
        case ms500  = 500
        case ms1000 = 1000
        case ms2000 = 2000

        public var cppEnumValue: MblMwAlsLtr329MeasurementRate {
            switch self {
                case .ms50: return MBL_MW_ALS_LTR329_RATE_50ms
                case .ms100: return MBL_MW_ALS_LTR329_RATE_100ms
                case .ms200: return MBL_MW_ALS_LTR329_RATE_200ms
                case .ms500: return MBL_MW_ALS_LTR329_RATE_500ms
                case .ms1000: return MBL_MW_ALS_LTR329_RATE_1000ms
                case .ms2000: return MBL_MW_ALS_LTR329_RATE_2000ms
            }
        }
    }

}
