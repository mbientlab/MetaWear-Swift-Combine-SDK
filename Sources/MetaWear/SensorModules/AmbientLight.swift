// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

/// Lux (Illuminance)
public struct MWAmbientLight: MWStreamable, MWLoggable {

    /// Lux (Illuminance)
    public typealias DataType = Double
    public typealias RawDataType = UInt32
    public let signalName: MWNamedSignal = .ambientLight
    public let columnHeadings = ["Epoch", "Lux"]

    public var gain: Gain? = nil
    public var integrationTime: IntegrationTime? = nil
    public var rate: MeasurementRate? = nil
    public var needsConfiguration: Bool { gain != nil || integrationTime != nil || rate != nil }

    public init(gain: MWAmbientLight.Gain? = nil,
                integrationTime: MWAmbientLight.IntegrationTime? = nil,
                rate: MWAmbientLight.MeasurementRate? = nil) {
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
    static func ambientLight(rate: MWAmbientLight.MeasurementRate,
                             gain: MWAmbientLight.Gain,
                             integrationTime: MWAmbientLight.IntegrationTime) -> Self {
        Self(gain: gain, integrationTime: integrationTime, rate: rate)
    }
}

public extension MWLoggable where Self == MWAmbientLight {
    static func ambientLight(rate: MWAmbientLight.MeasurementRate,
                             gain: MWAmbientLight.Gain,
                             integrationTime: MWAmbientLight.IntegrationTime) -> Self {
        Self(gain: gain, integrationTime: integrationTime, rate: rate)
    }
}

// MARK: - C++ Constants

public extension MWAmbientLight {

    enum Gain: Int, CaseIterable, IdentifiableByRawValue {
        case x1  = 1
        case x2  = 2
        case x4  = 4
        case x8  = 8
        case x48 = 48
        case x96 = 96

        public var cppEnumValue: MblMwAlsLtr329Gain {
            switch self {
                case .x1: return MBL_MW_ALS_LTR329_GAIN_1X
                case .x2: return MBL_MW_ALS_LTR329_GAIN_2X
                case .x4: return MBL_MW_ALS_LTR329_GAIN_4X
                case .x8: return MBL_MW_ALS_LTR329_GAIN_8X
                case .x48: return MBL_MW_ALS_LTR329_GAIN_48X
                case .x96: return MBL_MW_ALS_LTR329_GAIN_96X
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
        /// 50 Hz
        case ms50   = 50
        /// 10 Hz
        case ms100  = 100
        /// 5 Hz
        case ms200  = 200
        /// 2 Hz
        case ms500  = 500
        /// 1 Hz
        case ms1000 = 1000
        /// 0.5 Hz
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

        public var freq: MWFrequency {
            .init(periodMs: rawValue)
        }

        /// Hz
        public var label: String {
            switch self {
                case .ms2000: return "0.5 Hz"
                default: return "\(1000 / rawValue) Hz"
            }
        }
    }

}
